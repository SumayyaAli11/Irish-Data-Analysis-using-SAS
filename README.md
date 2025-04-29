# 🏡 Kildare House Price Analysis (2010–2020) Using SAS

This project analyzes a decade of residential property prices in **County Kildare**, Ireland using **SAS**. Drawing from the national **Property Price Register**, the analysis explores spatial and temporal trends to offer insights valuable to buyers, policymakers, and urban planners.

---

## 📌 Problem Statement

- **Transparency Initiative**: The Property Price Register was launched in 2010 to promote transparency in Ireland’s residential property sales.
- **Focus Region**: This project narrows in on **County Kildare**, known for both its urban centers and rural towns.
- **Research Question**:  
  *How have house prices evolved across towns in County Kildare from 2010 to 2020? What spatial and temporal trends can be identified to guide decisions in the housing market?*

---

## 🧪 Methodology Overview

### 📥 Data Collection
- Consolidated Kildare-specific entries from annual CSV files spanning 2010–2020.

### 🧹 Data Cleaning
- **Town Name Extraction**: Used HASH lookup against a valid town list.
- **Manual Overrides**: Corrected common misspellings via `LEFT JOIN` with `override_map`.
- **Fuzzy Matching (SPEDIS)**: Applied `SPEDIS()` function to resolve unmatched towns with a similarity threshold of 30.
- **Filtering**: From 23,077 records, 19,813 remained after cleaning.

### 📊 Aggregation & Metrics
- Calculated average house prices and annual percentage changes for each town.

### 📈 Visual Analytics
- **Line Plot**: Top 5 towns by price growth across 10 years.
- **Boxplots**: Annual price variance by town.
- **Heatmap**: Town-wise price intensity over time.
- **Bubble Map**: Spatial distribution of prices in 2020.
- **National Comparison**: Overlaid national median prices for broader context.

---

## 🔍 Key Insights

### 🌆 Town-Level Growth
- **Highest Growth**:  
  - *Kilmeage* (185.7%)  
  - *Robertstown* (147.2%)
- **Negative Growth**:  
  - *Calverstown*  
  - *Carbury*

### 📈 Market Dynamics
- **Post-2013 Recovery**: General price increase aligning with economic recovery.
- **Luxury Market**: More outliers indicate rising high-end property transactions.
- **2020 Hotspots**:  
  - High Prices: *Naas*, *Leixlip*, *Maynooth*  
  - Low Prices: *Castledermot*, *Edenderry*
- **Heatmap Findings**: Notable intensification post-2014 in towns like *Sallins*, *Leixlip*, and *Newbridge*.

---

## 📌 Summary of Key Findings

- **Diverging Growth**: Contrast between booming towns like Kilmeage and stagnant areas like Carbury.
- **Urban-Rural Divide**: Persistent high prices in urban hubs vs. delayed growth in rural zones.
- **Broad Price Surge Post-2014**: Clear indication of macroeconomic recovery effects.
- **Segmented Market**: 2020 data shows a dual trend—luxury demand rising and affordability challenges increasing.

---

## 🛠️ Tools and Technologies

- **SAS Base Programming**
- `PROC SQL`, `PROC MEANS`, `PROC FREQ`, `PROC SGPLOT`
- **SPEDIS Function** for fuzzy matching
- Custom HASH lookups and JOINs for cleaning

---

## 👩‍💻 Author

**Sumayya Ali**  
MSc Data Science & Analytics – Maynooth University  
[GitHub](https://github.com/SumayyaAli11) • [LinkedIn](https://www.linkedin.com/in/sumayyaali/)

---

> 📬 *Contributions and suggestions are welcome. Please open an issue or submit a pull request if you'd like to collaborate or improve this project.*


