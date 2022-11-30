USE Housing; -- specifying schema
SET SQL_SAFE_UPDATES = 0; -- Disabling safe mode 
SET GLOBAL local_infile=1;-- to load the data
SET SESSION autocommit = 0;

# Raw Data imported via import wizard
DROP TABLE IF EXISTS Housing;
SELECT * 
FROM Housing;

# Replacing all the empty strings with NULL
UPDATE Housing 
SET
	UniqueID = IF(UniqueID = "", NULL, UniqueID),
    ParcelID = IF(ParcelId = "", NULL, ParcelID),
    LandUse = IF(LandUse = "", NULL, LandUse),
    PropertyAddress = IF(PropertyAddress = "", NULL, PropertyAddress),
    SaleDate = IF(SaleDate = "", NULL, SaleDate),
    SalePrice = IF(SalePrice = "", NULL, SalePrice),
    LegalReference = IF(LegalReference = "", NULL, LegalReference),
    SoldAsVacant = IF(SoldAsVacant = "", NULL, SoldAsVacant),
    OwnerName = IF(OwnerName = "", NULL, OwnerName),
    Acreage = IF(Acreage = "", NULL, Acreage),
    TaxDistrict = IF(TaxDistrict = "", NULL, TaxDistrict),
    LandValue = IF(LandValue = "", NULL, LandValue),
    BuildingValue = IF(BuildingValue = "", NULL, BuildingValue),
    TotalValue = IF(TotalValue = "", NULL, TotalValue),
    YearBuilt = IF(YearBuilt = "", NULL, YearBuilt),
    Bedrooms = IF(Bedrooms = "", NULL, Bedrooms),
    FullBath = IF(FullBath = "", NULL, FullBath),
    HalfBath = IF(HalfBath = "", NULL, HalfBath);
    
# Change the columne data type
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

# create a stored procedure to briefly look at the whole data    
DROP PROCEDURE IF EXISTS look;
DELIMITER $$
CREATE PROCEDURE look(IN num INT)
	BEGIN
		SELECT *
        FROM Housing
        LIMIT num;
	END$$
DELIMITER ;
    
# convert date column to date format
UPDATE Housing
SET SaleDate = STR_TO_DATE(SaleDate, "%m-%d-%Y");

# populate missing property address data
UPDATE Housing AS t1
JOIN Housing AS t2
ON t1.ParcelID = t2.ParcelID AND
   t1.PropertyAddress IS NULL AND
   t2.PropertyAddress IS NOT NULL AND
   t1.UniqueID != t2.UniqueID
SET t1.PropertyAddress = IFNULL(t1.PropertyAddress, t2.PropertyAddress); 

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

# Trim the white spaces for each row of the newly created columns
UPDATE Housing
SET
	OwnerSplitAddress = TRIM(OwnerSplitAddress),
    OwnerSplitCity = TRIM(OwnerSplitCity),
    OwnerSplitState = TRIM(OwnerSplitState);

# Fill in the empty strings with NULL
UPDATE Housing
SET
	OwnerSplitAddress = IF(OwnerSplitAddress = "", NULL, OwnerSplitAddress),
    OwnerSplitCity = IF(OwnerSplitCity = "", NULL, OwnerSplitCity),
    OwnerSplitState = IF(OwnerSplitState = "", NULL, OwnerSplitState);

# Change Y / N to Yes / No
SELECT SoldAsVacant, COUNT(*) AS tot
FROM Housing
GROUP BY SoldAsVacant;

UPDATE Housing
SET SoldAsVacant = CASE
		WHEN SoldAsVacant = "Y" THEN "Yes"
        WHEN SoldAsVacant = "N" THEN "No"
        ELSE SoldAsVacant
		END;

# Remove Duplicates in CTE
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

SELECT *
FROM Housing;

