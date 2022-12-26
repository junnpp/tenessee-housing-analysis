# Tenessee Housing Analysis

Import, clean, analyze, and visualize [Tenessee housing data](https://github.com/AlexTheAnalyst/PortfolioProjects/blob/main/Nashville%20Housing%20Data%20for%20Data%20Cleaning.xlsx) using [MySQL]() and Tableau. The raw dataset `Housing.csv` contains about 57,000 rows and each row consists of 19 columns.

## `Housing.csv`

|variable          |class     |description |
|:-----------------|:---------|:-----------|
|UniqueID          |character | Key Column |
|ParcelID          |character | APN (a number assigned to parcels of real property by the tax assessor) |
|LandUse           |character | Type of land use |
|PropertyAddress   |character | Physical address of the property |
|SaleDate          |date      | Date of the sale  |
|SalePrice         |integer   | Sale price |
|LegalReference    |character | Legal citation |
|SoldAsVacant      |character | Whether or not the property was sold as vacant (Yes/No) |
|OwnerName         |character | Owner Name |
|OwnerAddress      |character | Onwer Address |
|Acreage           |double    | Area of the property in acre |
|TaxDistrict       |character | Tax District of the property |
|LandValue         |double    | Land value of the property |
|BuildingValue     |double    | Building structure value of the property |
|TotalValue        |double    | Total value of the property |
|Bedrooms          |double    | Number of bedrooms |
|FullBath          |double    | Number of full bathrooms |
|HalfBath          |double    | Number of half bathrooms |

## Cleaning Process

1. Change data type of each column

```mysql
ALTER TABLE Housing MODIFY SalePrice INTEGER;
ALTER TABLE Housing MODIFY UniqueID INTEGER;
ALTER TABLE Housing MODIFY Acreage DOUBLE;
ALTER TABLE Housing MODIFY LandValue INTEGER;
ALTER TABLE Housing MODIFY BuildingValue INTEGER;
ALTER TABLE Housing MODIFY TotalValue INTEGER;
ALTER TABLE Housing MODIFY YearBuilt INTEGER;
ALTER TABLE Housing MODIFY Bedrooms INTEGER;
ALTER TABLE Housing MODIFY FullBath INTEGER;
ALTER TABLE Housing MODIFY HalfBath INTEGER;

```

2. Convert `SaleDate` into datetime format

```mysql
UPDATE Housing
SET SaleDate = STR_TO_DATE(SaleDate, "%m-%d-%Y");
```

3. Populate missing property address data
There are few rows with missing `PropertyAddress` value which can be filled with property address of other rows with the same `ParcelID` and `UniqueID`. Use self join to population those missing values.

```mysql
UPDATE Housing AS t1
JOIN Housing AS t2
ON t1.ParcelID = t2.ParcelID AND
   t1.PropertyAddress IS NULL AND
   t2.PropertyAddress IS NOT NULL AND
   t1.UniqueID != t2.UniqueID
SET t1.PropertyAddress = IFNULL(t1.PropertyAddress, t2.PropertyAddress); 
```

4. Split `PropertyAddress` and `OwnerAddress` into separate columns

```mysql
# Splitting PropertyAddress into seperate columns (Address, City, State)
SELECT
	SUBSTR(PropertyAddress, 1, INSTR(PropertyAddress, ",") - 1) AS Address,
    SUBSTR(PropertyAddress, INSTR(PropertyAddress, ",") + 1, LENGTH(PropertyAddress)) AS Address
FROM Housing;

ALTER TABLE Housing
ADD PropertySplitAddress varchar(255);

UPDATE Housing
SET PropertySplitAddress = SUBSTR(PropertyAddress, 1, INSTR(PropertyAddress, ",") - 1);

ALTER TABLE Housing
ADD PropertySplitCity varchar(255);

UPDATE Housing
SET PropertySplitCity = SUBSTR(PropertyAddress, INSTR(PropertyAddress, ",") + 1, LENGTH(PropertyAddress));

# Trim the white spaces for each row of the newly created columns
UPDATE Housing
SET
	PropertySplitAddress = TRIM(PropertySplitAddress),
    PropertySplitCity = TRIM(PropertySplitCity);
    

# Splitting OnwerAddress in the same manner
SELECT
	SUBSTRING_INDEX(OwnerAddress, ",", 1) AS Address,
    SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 2), ",", -1),
    SUBSTRING_INDEX(OwnerAddress, ",", -1)
FROM Housing;

ALTER TABLE Housing
ADD OwnerSplitAddress varchar(255);

UPDATE Housing
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ",", 1);

ALTER TABLE Housing
ADD OwnerSplitCity varchar(255);

UPDATE Housing
SET OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ",", 2), ",", -1);

ALTER TABLE Housing
ADD OwnerSplitState varchar(255);

UPDATE Housing
SET OwnerSplitState = SUBSTRING_INDEX(OwnerAddress, ",", -1);
```
5. Change `Y` and `N` to `Yes` and `No`

```mysql
SELECT SoldAsVacant, COUNT(*) AS tot
FROM Housing
GROUP BY SoldAsVacant;

UPDATE Housing
SET SoldAsVacant = CASE
		WHEN SoldAsVacant = "Y" THEN "Yes"
        WHEN SoldAsVacant = "N" THEN "No"
        ELSE SoldAsVacant
		END;
```

6. Remove duplicates and unused columns

```mysql
WITH RowNumCte AS (
SELECT
	*,
	ROW_NUMBER() OVER(
    PARTITION BY ParcelID,
				 PropertySplitAddress,
                 PropertySplitCity,
				 SalePrice,
                 SaleDate,
                 LegalReference
                 ORDER BY UniqueID) AS row_num
FROM Housing
)

# Deleting Duplicates
DELETE t1 /* you have to use the alias here*/ FROM Housing AS t1
JOIN RowNumCte AS t2
ON t1.ParcelID = t2.ParcelID AND
   t1.PropertySplitAddress = t2.PropertySplitAddress AND
   t1.PropertySplitCity = t2.PropertySplitCity AND
   t1.SalePrice = t2.SalePrice AND
   t1.SaleDate = t2.SaleDate AND
   t1.LegalReference = t2.LegalReference
WHERE row_num != 1;
	
# Delete Unused Columns
ALTER TABLE Housing
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress;

```