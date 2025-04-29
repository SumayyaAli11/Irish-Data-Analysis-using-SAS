/* Step 1: Import the dataset from CSV */
proc import datafile="/home/u64156064/sasuser.v94/Irish_Residential/combined_data_Kildare.csv"
    out=Kildare_data
    dbms=csv
    replace;
    getnames=yes;
run;

/* Step 2: Create a list of valid town names for county Kildare*/
data valid_towns;
    input Clean_Town $50.;
    datalines;
Allenwood
Athgarvan
Athy
Ballitore
Ballymore_Eustace
Ballyoulster
Ballyroe
Blessington
Brownstown
Calverstown
Carragh
Carbury
Castledermot
Celbridge
Clane
Coill_Dubh
Cut_Bush
Derrinturn
Edenderry
Grangemore
Johnstown
Johnstownbridge
Kilberry
Kilcock
Kilcullen
Kildangan
Kill
Kilmead
Kilmeage
Kilteel
Ladytown
Leixlip
Maynooth
Milltown
Monasterevin
Naas
Narraghmore
Newbridge
Nurney
Prosperous
Rathangan
Rathcoffey
Robertstown
Sallins
Straffan
Suncroft
;
run;

/* Step 3: Extract Town from address using last matching valid town */
data enhanced_clean;
    if _n_ = 1 then do;
        declare hash towns(dataset: "valid_towns");
        towns.defineKey('Clean_Town');
        towns.defineDone();
    end;

    set Kildare_data;
    length Clean_Town $50. Town $50. Word $100. address_lower $500. last_valid_town $50. candidate $100.;
    Price_clean = input(compress(Price, ","), best.);
    SaleDate = 'Sale Date'n;
    format SaleDate date9.;
    Year = year(SaleDate);

    address_lower = lowcase(Address);
    Town = "";
    last_valid_town = "";

    /* Step 1: Scan all words and track the last matched valid town */
    do i = 1 to countw(address_lower, ' ,');
        Word = propcase(compress(scan(address_lower, i, ' ,'), ",."));
        if towns.check(key: Word) = 0 then last_valid_town = Word;
    end;

    /* Step 2: Assign last valid matched town */
    if last_valid_town ne "" then Town = last_valid_town;

    /* Step 2b: Special case - if 'kildare' in address, try word before last comma */
    if index(address_lower, 'kildare') > 0 and countc(Address, ',') >= 2 then do;
        last_comma_index = countc(Address, ',');
        candidate = strip(scan(Address, last_comma_index - 1, ','));
        candidate = propcase(compress(candidate, ",."));
        if towns.check(key: candidate) = 0 then Town = candidate;
    end;

    /* Step 3: Fallback to last word if still not found */
    if Town = "" then Town = propcase(compress(scan(address_lower, -1, ' ,'), ",."));

    drop i Word last_valid_town address_lower candidate last_comma_index Clean_Town;
run;


proc freq data=enhanced_clean;
    tables Town / nocum nopercent;
run;

/* Step 4: Manually override known misclassified or misspelled towns */
data override_map;
    infile datalines dlm='~' dsd;
    length Raw_Town $100 Correct_Town $50;
    input Raw_Town $ Correct_Town $;

    /* Normalize for join */
    Raw_Town = strip(lowcase(compress(Raw_Town, ",.")));
    Correct_Town = strip(Correct_Town);
    datalines;
celbrdige~Celbridge
celbrodge~Celbridge
celebridge~Celbridge
celeridge~Celbridge
cellbridge~Celbridge
cellebridge~Celbridge
leixkp~Leixlip
leixlep~Leixlip
straffon~Straffan
straffen~Straffan
strafan~Straffan
newbride~Newbridge
newbridgte~Newbridge
newbridgw~Newbridge
kildard~Kildare
aathgarvan~Athgarvan
athgarven~Athgarvan
athgarvin~Athgarvan
;
run;

/* Step 5: Normalize and prepare towns for joining with override map */
data step_with_override;
    set enhanced_clean;
    length town_lower $100.;
    town_lower = strip(lowcase(compress(Town, ",.")));
run;

/* Step 6: Apply manual overrides */
proc sql;
    create table base_town_assigned as
    select 
        a.*,
        coalesce(b.Correct_Town, a.Town) as Base_Town
    from step_with_override a
    left join override_map b
    on a.town_lower = b.Raw_Town;
quit;


/* Step 7: Fuzzy match Base_Town against valid towns using SPEDIS */
proc sql;
    create table fuzzy_matched_towns as
    select distinct 
        strip(Base_Town) as Raw_Town,
        b.Clean_Town,
        spedis(lowcase(Base_Town), lowcase(b.Clean_Town)) as Distance
    from base_town_assigned, valid_towns b
    where spedis(lowcase(Base_Town), lowcase(b.Clean_Town)) < 30
    order by Raw_Town, Distance;
quit;

/* Step 8: Keep only the best (lowest distance) fuzzy match per town */
proc sort data=fuzzy_matched_towns out=sorted_towns force;
    by Raw_Town Distance;
run;


data fuzzy_best_match;
    set fuzzy_matched_towns;
    by Raw_Town;
    if first.Raw_Town;
run;

/* Step 9: Final join to assign cleaned town */
proc sql;
    create table final_data as
    select 
        a.*,
        coalesce(b.Clean_Town, a.Base_Town) as Clean_Town
    from base_town_assigned a
    left join fuzzy_best_match b
    on lowcase(a.Base_Town) = lowcase(b.Raw_Town);
quit;

/* Step 10: Final cleanup - ensure only valid towns are included */
proc sql;
    create table final_cleaned_data as
    select a.*
    from final_data a
    inner join valid_towns b
    on lowcase(a.Clean_Town) = lowcase(b.Clean_Town);
quit;

/* 
   Create a cleaned and simplified dataset with only necessary columns,
   and rename them for better readability and consistency.
*/
data final_output;
    /* 
       Read from the cleaned dataset, keeping only selected variables:
       - Address
       - Clean_Town (standardized town name)
       - Price_clean (numeric cleaned price)
       - SaleDate (formatted date)
       - Year (year extracted from SaleDate)
       - Description of Property, VAT Exclusive, Property Size Description (original columns with spaces)
    */
    set final_cleaned_data(
        keep=Address Clean_Town Price_clean SaleDate Year 
             'Description of Property'n 'VAT Exclusive'n 'Property Size Description'n
    );

    /* 
       Rename selected columns to more intuitive names:
       - Price_clean          → Price_Euro
       - SaleDate             → Sale_Date
       - Clean_Town           → Town (simplifies the name for final output)
       - 'Description of Property'n  → Property_Description
       - 'VAT Exclusive'n     → VAT_Status
       - 'Property Size Description'n → Size_Description
    */
    rename 
        Price_clean                     = Price_Euro
        SaleDate                        = Sale_Date
        'Description of Property'n      = Property_Description
        'VAT Exclusive'n                = VAT_Status
        'Property Size Description'n    = Size_Description
        clean_town                      = Town;
run;


proc contents data=final_output;
run;


/* Step 11: Frequency check of final cleaned towns */
proc freq data=final_output;
    tables Town / nocum nopercent;
run;

proc freq data=final_output;
    tables Price_Euro Year / missing;
run;

proc means data=final_output n nmiss;
    var Price_Euro Year;
run;

proc print data=final_output;
    title "All Records from final_output";
run;

/*---------------------------
1. CALCULATE TOWN-WISE PRICE GROWTH (2010–2020)
---------------------------*/
proc sql;
    create table town_growth as
    select 
        Town,
        avg(case when Year = 2010 then Price_Euro end) as Price_2010,
        avg(case when Year = 2020 then Price_Euro end) as Price_2020
    from final_output
    where Year in (2010, 2020)
    group by Town
    having not missing(Price_2010) and not missing(Price_2020);
quit;

data town_growth;
    set town_growth;
    /* Calculate percent change in house prices from 2010 to 2020 */
    Percent_Change = ((Price_2020 - Price_2010) / Price_2010) * 100;
run;

proc sort data=town_growth;
    by descending Percent_Change;
run;

/*---------------------------------------------------------
 STEP 1: Begin PDF Report Output
---------------------------------------------------------*/
ods pdf file="/home/u64156064/kildare_house_price_report.pdf" 
    style=HTMLBlue startpage=never;
title "Kildare House Price Trends (2010–2020)";
footnote "Generated using SAS | © Irish Residential Property Price Register";

/*---------------------------------------------------------
 STEP 2: Town-Wise Growth Analysis (2010 vs 2020)
---------------------------------------------------------*/
proc sql;
    create table town_growth as
    select 
        Town,
        avg(case when Year = 2010 then Price_Euro end) as Price_2010,
        avg(case when Year = 2020 then Price_Euro end) as Price_2020
    from final_output
    where Year in (2010, 2020)
    group by Town
    having not missing(Price_2010) and not missing(Price_2020);
quit;

data town_growth;
    set town_growth;
    Percent_Change = ((Price_2020 - Price_2010) / Price_2010) * 100;
run;

proc sort data=town_growth;
    by descending Percent_Change;
run;


data town_growth_colored;
    set town_growth;
    length Growth_Band $20;
    if Percent_Change >= 100 then Growth_Band = "Very High";
    else if Percent_Change >= 50 then Growth_Band = "High";
    else if Percent_Change >= 0 then Growth_Band = "Moderate";
    else Growth_Band = "Negative";
run;

title "Top Towns by % House Price Growth (2010–2020)";
proc sgplot data=town_growth_colored;
    vbar Town / response=Percent_Change group=Growth_Band datalabel 
        groupdisplay=cluster;
    yaxis label="% Change in Price";
    xaxis display=(nolabel);
    keylegend / title="Growth Category";
run;



/*---------------------------------------------------------
 STEP 3: Line Plot of Top 5 Towns by Growth
---------------------------------------------------------*/
proc sql;
    create table top_trending_towns as
    select Town
    from town_growth(obs=5)
    order by Percent_Change desc;
quit;

proc sql;
    create table top_town_prices as
    select a.Town, a.Year, avg(a.Price_Euro) as Avg_Price
    from final_output a
    inner join top_trending_towns b
    on a.Town = b.Town
    where 2010 <= a.Year <= 2020
    group by a.Town, a.Year;
quit;

title "Price Trends for Top 5 Fastest Growing Towns";
proc sgplot data=top_town_prices;
    series x=Year y=Avg_Price / group=Town 
        lineattrs=(thickness=2)
        markers markerattrs=(symbol=circlefilled size=8);
    yaxis label="Average House Price (€)";
    xaxis label="Year";
    keylegend / title="Town";
run;



/*---------------------------------------------------------
 STEP 4: Boxplots of Yearly and Town-wise Price Distribution
---------------------------------------------------------*/

title "Distribution of House Prices by Year (2010–2020)";
proc sgplot data=final_output;
    vbox Price_Euro / category=Year;
    yaxis label="Price (€)" max=4000000;
run;

title "Town-wise House Price Distribution (2020)";
proc sgplot data=final_output;
    where Year = 2020;
    vbox Price_Euro / category=Town;
    yaxis label="Price (€)" max=1500000;
run;


/*---------------------------------------------------------
 STEP 5: Heatmap – Average Price per Town per Year
---------------------------------------------------------*/
proc sql;
    create table price_matrix as
    select Town, Year, avg(Price_Euro) as Avg_Price
    from final_output
    where 2010 <= Year <= 2020
    group by Town, Year;
quit;

title "Heatmap of Average House Prices by Town and Year";
proc sgplot data=price_matrix;
    heatmapparm x=Year y=Town colorresponse=Avg_Price / 
        colormodel=(cxeff3ff cx08519c);
    xaxis display=(nolabel);
    yaxis discreteorder=data display=(nolabel);
run;


/*---------------------------------------------------------
 STEP 6: National Median Price Trend (2010–2020)
---------------------------------------------------------*/
proc means data=final_output noprint;
    class Year;
    var Price_Euro;
    output out=median_prices median=Median_Price;
run;

title "National Median House Price Trend (2010–2020)";
proc sgplot data=median_prices(where=(_TYPE_ = 1));
    series x=Year y=Median_Price / markers lineattrs=(thickness=2);
run;


/*---------------------------------------------------------
 STEP 7: Town-wise Boxplot Comparison (2010 vs 2020)
---------------------------------------------------------*/
title "House Price Spread by Town (2010 vs 2020)";
proc sgplot data=final_output;
    where Year in (2010, 2020);
    vbox Price_Euro / category=Town group=Year 
        groupdisplay=cluster 
        fillattrs=(transparency=0.3) 
        lineattrs=(thickness=1 color=black);
    yaxis label="Price (€)" values=(0 to 1500000 by 100000);
    xaxis display=(nolabel);
    keylegend / title="Year";
run;


/*---------------------------------------------------------
 STEP 8: Bubble Map – Avg Price by Town (2020)
---------------------------------------------------------*/
data final_output_clean;
    set final_output;
    Town_Clean = strip(upcase(Town));
run;

data town_coords_raw;
	length Town $50;
    input Town $ Latitude Longitude;
    datalines;
Allenwood 53.2920 -6.8120
Athgarvan 53.1526 -6.7765
Athy 52.9917 -6.9806
Ballitore 52.8983 -6.8156
Ballymore_Eustace 53.1367 -6.5851
Ballyoulster 53.3315 -6.5430
Ballyroe 52.9944 -6.9861
Blessington 53.1704 -6.5314
Brownstown 53.1650 -6.8170
Calverstown 53.0908 -6.7880
Carbury 53.3706 -6.9740
Carragh 53.2508 -6.7071
Castledermot 52.9133 -6.8375
Celbridge 53.3386 -6.5439
Clane 53.2914 -6.6867
Derrinturn 53.3377 -6.9901
Edenderry 53.3450 -7.0490
Grangemore 53.2194 -6.8417
Johnstown 53.2742 -6.6208
Johnstownbridge 53.3810 -6.9740
Kilcock 53.4013 -6.6710
Kilcullen 53.1275 -6.7426
Kildangan 52.9962 -6.9972
Kill 53.2700 -6.5900
Kilmead 52.9870 -6.8890
Kilmeage 53.2289 -6.8062
Kilteel 53.2662 -6.5481
Ladytown 53.2420 -6.7330
Leixlip 53.3660 -6.4865
Maynooth 53.3811 -6.5918
Milltown 53.1703 -6.7746
Monasterevin 53.1400 -7.0631
Naas 53.2200 -6.6667
Narraghmore 53.0170 -6.8680
Newbridge 53.1810 -6.7967
Nurney 52.9800 -6.9800
Prosperous 53.3040 -6.7530
Rathangan 53.2151 -6.9917
Rathcoffey 53.3446 -6.6533
Robertstown 53.2800 -6.8130
Sallins 53.2450 -6.6631
Straffan 53.3115 -6.5911
Suncroft 53.1050 -6.8850
;
run;

data coords;
    set town_coords;
    length Town_Clean $100.;  /* Ensure enough space for full town names */
    Town_Clean = strip(upcase(Town));
run;


/* Join Coordinates with Price Data */
proc sql;
    create table map_data as
    select 
        a.Town,
        avg(a.Price_Euro) as Avg_Price format=comma10.0,
        b.Latitude,
        b.Longitude
    from final_output_clean a
    left join coords b
    on a.Town_Clean = b.Town_Clean
    where a.Year = 2020
    group by a.Town, b.Latitude, b.Longitude
    having not missing(Latitude) and not missing(Longitude);
quit;

/* Optional: List towns not matched */
proc sql;
    create table unmatched_towns as
    select distinct a.Town, a.Town_Clean
    from final_output_clean a
    where a.Year = 2020
    and not exists (
        select 1 from coords b
        where a.Town_Clean = b.Town_Clean
    );
quit;

proc print data=unmatched_towns;
    title "Unmatched Towns in Coordinates File";
run;

proc sgmap plotdata=map_data;
    openstreetmap;

    bubble x=Longitude y=Latitude size=Avg_Price / 
        colorresponse=Avg_Price
        colormodel=(cx1a9850 cxffd700 cxcc0000)  /* Green → Yellow → Red */
        bradiusmin=4 bradiusmax=22               /* Bubble size range */
        datalabel=Town
        datalabelpos=right
        datalabelattrs=(color=black size=9 weight=bold)
        transparency=0.4
        name="AvgPriceBubble";

    gradlegend / title="Average Price (€)";
    title "Average House Prices by Town (2020)";
run;



proc sgplot data=town_price_map;
    bubble x=Longitude y=Latitude size=Avg_Price / 
        datalabel=Town
        colorresponse=Avg_Price
        colormodel=(cxf1eef6 cxd7b5d8 cxdf65b0 cce12525)
        datalabelattrs=(size=7 weight=bold color=black);
    xaxis label="Longitude";
    yaxis label="Latitude";
    title "Bubble Plot of Avg House Prices by Town (2020)";
run;


/*---------------------------------------------------------
 FINAL STEP: Close PDF Output
---------------------------------------------------------*/
ods pdf close;

