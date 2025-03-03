select top 10 * from FlatTable

select top 5* from tna.Rostering
select top 5* from tna.ShiftMst
select top 5* from dbo.ReqRec_EmployeeDetails
select top 5* from GeoConfig.EmployeesLocationMapping
select top 5* from GeoConfig.GeoConfigurationLocationMst
select top 5* from dbo.SETUP_EMPLOYEESTATUSMST

CREATE TABLE dbo.Flattable
(
    EmpCode VARCHAR(100) PRIMARY KEY,
    ed_Salutation VARCHAR(100) NULL,
    ed_firstname VARCHAR(100) NULL,
    ed_MiddleName VARCHAR(100) NULL,
    ed_lastname VARCHAR(100) NULL,
    ed_empid INT NULL,
    ED_Status INT NULL,
    ESM_EmpStatusDesc VARCHAR(100) NULL,
    IPCheckEnabled BIT NULL,
    LocationCheckEnabled BIT NULL,
    IPCheckEnabledOnMobile BIT NULL,
    PunchIn BIT NULL,
    PunchOut BIT NULL,
    ShiftDetails NVARCHAR(MAX) NULL,  -- Storing JSON as NVARCHAR(MAX)
    LocationDetails NVARCHAR(MAX) NULL,  -- Storing JSON as NVARCHAR(MAX)
    IPRange NVARCHAR(MAX) NULL  -- Storing JSON as NVARCHAR(MAX)
);

INSERT INTO flattable (
    EmpCode,
    ed_Salutation,
    ed_firstname,
    ed_MiddleName,
    ed_lastname,
    ed_empid,
    ED_Status,
    ESM_EmpStatusDesc,
    IPCheckEnabled,
    LocationCheckEnabled,
    IPCheckEnabledOnMobile,
    PunchIn,
    PunchOut,
    ShiftDetails,
    LocationDetails,
    IPRange
)
SELECT 
    re.ed_empcode AS EmpCode,
    re.ed_Salutation, 
    re.ed_firstname, 
    re.ed_MiddleName, 
    re.ed_lastname,
    re.ed_empid,
    re.ED_Status,
    se.ESM_EmpStatusDesc,
    gc_bool.IPCheckEnabled,
    gc_bool.LocationCheckEnabled,
    gc_bool.IPCheckEnabledOnMobile,
    gc_bool.PunchIn,
    gc_bool.PunchOut,

    -- Shift details JSON
    (
      SELECT 
          ro_inner.ShiftID,
          MIN(ro_inner.AttMode) AS AttMode,
          MIN(ro_inner.DiffIN) AS DiffIN,
          MIN(ro_inner.DiffOUT) AS DiffOUT,
          MIN(ro_inner.TotalworkedMinutes) AS TotalworkedMinutes,
          MIN(ro_inner.RegIN) AS RegIN,
          MIN(ro_inner.RegOut) AS RegOut,
          MIN(ro_inner.FromMin) AS FromMin,
          MIN(ro_inner.ToMin) AS ToMin,
          MIN(sht_inner.ShiftName) AS ShiftName,
          MIN(ro_inner.Date) AS ShiftStart,
          MAX(ro_inner.Date) AS ShiftEnd
      FROM tna.Rostering AS ro_inner
      INNER JOIN tna.ShiftMst AS sht_inner 
          ON ro_inner.ShiftId = sht_inner.ShiftId
      WHERE ro_inner.EmpCode = re.ed_empcode
      GROUP BY ro_inner.ShiftID
      FOR JSON PATH
    ) AS ShiftDetails,

    -- Location details JSON
    (
      SELECT 
          gg.LocationID,
          MIN(gg.georange) AS georange,
          CAST(MAX(CAST(gg.rangeinkm AS int)) AS bit) AS rangeinkm,
          MIN(gl.Latitude) AS Latitude,
          MIN(gl.Longitude) AS Longitude,
          MIN(gg.FromDate) AS FromDate,
          MIN(gg.ToDate) AS ToDate,
          MIN(gl.LocationAlias) AS LocationAlias
      FROM tna.Rostering AS ro_loc
      INNER JOIN GeoConfig.EmployeesLocationMapping AS gg 
          ON ro_loc.EmpCode = gg.EmployeeCode
      INNER JOIN GeoConfig.GeoConfigurationLocationMst gl
          ON gg.LocationID = gl.ID
      WHERE ro_loc.EmpCode = re.ed_empcode
      GROUP BY gg.LocationID
      FOR JSON PATH
    ) AS LocationDetails,

    -- IP Range JSON
    (
        SELECT 
            geoip.IPFrom,
            geoip.IPTo 
        FROM GeoConfig.GeoConfigurationIPMaster geoip  
        WHERE geoip.GeoConfigurationID IN 
        (
            SELECT DISTINCT gl_sub.ID
            FROM GeoConfig.GeoConfigurationLocationMst gl_sub
            INNER JOIN GeoConfig.EmployeesLocationMapping gg_sub
                ON gl_sub.ID = gg_sub.LocationID
            WHERE gg_sub.EmployeeCode = re.ed_empcode
        )
        FOR JSON PATH
    ) AS IPRange

FROM reqrec_employeedetails AS re
INNER JOIN dbo.SETUP_EMPLOYEESTATUSMST AS se 
    ON re.ED_Status = se.ESM_EmpStatusID

-- Compute boolean flags from geo config tables as separate columns
CROSS APPLY (
    SELECT 
        CASE WHEN CAST(MAX(CAST(gl.IPCheckEnabled AS INT)) AS BIT) = 1 THEN 'true' ELSE 'false' END AS IPCheckEnabled,
        CASE WHEN CAST(MAX(CAST(gl.LocationCheckEnabled AS INT)) AS BIT) = 1 THEN 'true' ELSE 'false' END AS LocationCheckEnabled,
        CASE WHEN CAST(MAX(CAST(gl.IPCheckEnabledOnMobile AS INT)) AS BIT) = 1 THEN 'true' ELSE 'false' END AS IPCheckEnabledOnMobile,
        CASE WHEN CAST(MAX(CAST(el.PunchIn AS INT)) AS BIT) = 1 THEN 'true' ELSE 'false' END AS PunchIn,
        CASE WHEN CAST(MAX(CAST(el.PunchOut AS INT)) AS BIT) = 1 THEN 'true' ELSE 'false' END AS PunchOut
    FROM GeoConfig.GeoConfigurationLocationMst gl
    INNER JOIN GeoConfig.EmployeesLocationMapping el 
        ON gl.ID = el.LocationId
) AS gc_bool

WHERE EXISTS (
    SELECT 1
    FROM tna.Rostering AS ro
    WHERE ro.EmpCode = re.ed_empcode
)
ORDER BY re.ed_empcode ASC;


select top 10 * from flattb;
