-- ============================================================
-- PROG6212 - RACE DAY MANAGEMENT SYSTEM
-- SECTION C - FINAL SQL DATABASE SCRIPT
-- Platform: Microsoft SQL Server / SSMS
-- ============================================================
-- This version matches the final ERD:
-- Organiser -> Event -> Race_Category -> Enrollment
-- Participant -> Enrollment
-- Enrollment -> Payment
-- Enrollment -> Race_Result
-- ============================================================


-- ============================================================
-- CREATE DATABASE
-- ============================================================

CREATE DATABASE RaceDayDB;
GO

USE RaceDayDB;
GO


-- ============================================================
-- 1. ORGANISER TABLE
-- ============================================================

CREATE TABLE Organiser
(
    Organiser_ID INT IDENTITY(1,1) PRIMARY KEY,
    Organiser_Name VARCHAR(100) NOT NULL,
    Email VARCHAR(150) NOT NULL UNIQUE,
    Phone_Number VARCHAR(20) NOT NULL
);


-- ============================================================
-- 2. EVENT TABLE
--
-- Distance_KM is NOT stored here because one Event can have
-- different race distances through Race_Category.
-- ============================================================

CREATE TABLE [Event]
(
    Event_ID INT IDENTITY(1,1) PRIMARY KEY,
    Organiser_ID INT NOT NULL,
    Event_Name VARCHAR(150) NOT NULL,
    [Description] VARCHAR(500) NOT NULL,
    Event_Date DATE NOT NULL,
    Location VARCHAR(150) NOT NULL,
    Event_Type VARCHAR(30) NOT NULL,
    [Status] VARCHAR(30) NOT NULL DEFAULT 'Planned',
    Closing_Date DATE NOT NULL,

    CONSTRAINT FK_Event_Organiser
        FOREIGN KEY (Organiser_ID)
        REFERENCES Organiser(Organiser_ID),

    CONSTRAINT CK_Event_Type
        CHECK (Event_Type IN ('Run', 'Walk', 'Cycle')),

    CONSTRAINT CK_Event_Status
        CHECK
        (
            [Status] IN
            ('Planned', 'Open', 'Closed', 'Completed', 'Cancelled')
        ),

    CONSTRAINT CK_Event_Closing_Date
        CHECK (Closing_Date <= Event_Date)
);


-- ============================================================
-- 3. RACE CATEGORY TABLE
--
-- Distance_KM belongs here because one Event can offer
-- different distances.
-- ============================================================

CREATE TABLE Race_Category
(
    Category_ID INT IDENTITY(1,1) PRIMARY KEY,
    Event_ID INT NOT NULL,
    Category_Name VARCHAR(100) NOT NULL,
    Distance_KM DECIMAL(6,2) NOT NULL,
    Entry_Fee DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    Max_Participants INT NOT NULL,
    Current_Participants INT NOT NULL DEFAULT 0,

    CONSTRAINT FK_Race_Category_Event
        FOREIGN KEY (Event_ID)
        REFERENCES [Event](Event_ID),

    CONSTRAINT UQ_Race_Category_Event_Name
        UNIQUE (Event_ID, Category_Name),

    CONSTRAINT CK_Race_Category_Distance
        CHECK (Distance_KM > 0),

    CONSTRAINT CK_Race_Category_Entry_Fee
        CHECK (Entry_Fee >= 0),

    CONSTRAINT CK_Race_Category_Max_Participants
        CHECK (Max_Participants > 0),

    CONSTRAINT CK_Race_Category_Current_Participants
        CHECK
        (
            Current_Participants >= 0
            AND Current_Participants <= Max_Participants
        )
);


-- ============================================================
-- 4. PARTICIPANT TABLE
-- ============================================================

CREATE TABLE Participant
(
    Participant_ID INT IDENTITY(1,1) PRIMARY KEY,
    First_Name VARCHAR(80) NOT NULL,
    Last_Name VARCHAR(80) NOT NULL,
    Date_Of_Birth DATE NOT NULL,
    Gender VARCHAR(20) NOT NULL,
    Email VARCHAR(150) NOT NULL UNIQUE,
    Phone_Number VARCHAR(20) NOT NULL
);


-- ============================================================
-- 5. ENROLLMENT TABLE
--
-- Enrollment is the junction entity between Participant
-- and Race_Category.
--
-- Event_ID is not stored here because the Event can already
-- be reached through Category_ID -> Race_Category.Event_ID.
-- ============================================================

CREATE TABLE Enrollment
(
    Enrollment_ID INT IDENTITY(1,1) PRIMARY KEY,
    Participant_ID INT NOT NULL,
    Category_ID INT NOT NULL,
    Enrollment_Date DATE NOT NULL DEFAULT GETDATE(),
    Race_Number VARCHAR(30) NOT NULL UNIQUE,
    Enrollment_Status VARCHAR(30) NOT NULL DEFAULT 'Pending',

    CONSTRAINT FK_Enrollment_Participant
        FOREIGN KEY (Participant_ID)
        REFERENCES Participant(Participant_ID),

    CONSTRAINT FK_Enrollment_Race_Category
        FOREIGN KEY (Category_ID)
        REFERENCES Race_Category(Category_ID),

    CONSTRAINT UQ_Enrollment_Participant_Category
        UNIQUE (Participant_ID, Category_ID),

    CONSTRAINT CK_Enrollment_Status
        CHECK
        (
            Enrollment_Status IN
            ('Pending', 'Confirmed', 'Cancelled')
        )
);


-- ============================================================
-- 6. PAYMENT TABLE
--
-- One Enrollment can have zero, one or many payment attempts.
-- ============================================================

CREATE TABLE Payment
(
    Payment_ID INT IDENTITY(1,1) PRIMARY KEY,
    Enrollment_ID INT NOT NULL,
    Amount DECIMAL(10,2) NOT NULL,
    Payment_Date DATE NOT NULL DEFAULT GETDATE(),
    Payment_Method VARCHAR(50) NOT NULL,
    Payment_Status VARCHAR(30) NOT NULL DEFAULT 'Pending',

    CONSTRAINT FK_Payment_Enrollment
        FOREIGN KEY (Enrollment_ID)
        REFERENCES Enrollment(Enrollment_ID),

    CONSTRAINT CK_Payment_Amount
        CHECK (Amount >= 0),

    CONSTRAINT CK_Payment_Status
        CHECK
        (
            Payment_Status IN
            ('Pending', 'Paid', 'Failed', 'Refunded')
        )
);


-- ============================================================
-- 7. RACE RESULT TABLE
--
-- One Enrollment can have at most one Race_Result.
-- The UNIQUE Enrollment_ID enforces the 0..1 relationship.
--
-- Completion_Time is not stored because it is calculated from
-- Finish_Time - Start_Time.
-- ============================================================

CREATE TABLE Race_Result
(
    Result_ID INT IDENTITY(1,1) PRIMARY KEY,
    Enrollment_ID INT NOT NULL UNIQUE,
    Start_Time DATETIME2 NULL,
    Finish_Time DATETIME2 NULL,
    Overall_Position INT NULL,
    Result_Status VARCHAR(30) NOT NULL DEFAULT 'Pending',

    CONSTRAINT FK_Race_Result_Enrollment
        FOREIGN KEY (Enrollment_ID)
        REFERENCES Enrollment(Enrollment_ID),

    CONSTRAINT CK_Race_Result_Time
        CHECK
        (
            Finish_Time IS NULL
            OR Start_Time IS NULL
            OR Finish_Time >= Start_Time
        ),

    CONSTRAINT CK_Race_Result_Position
        CHECK
        (
            Overall_Position IS NULL
            OR Overall_Position > 0
        ),

    CONSTRAINT CK_Race_Result_Status
        CHECK
        (
            Result_Status IN
            ('Pending', 'Completed', 'Did Not Finish', 'Disqualified')
        ),

    CONSTRAINT CK_Race_Result_Completed_Data
        CHECK
        (
            Result_Status <> 'Completed'
            OR
            (
                Start_Time IS NOT NULL
                AND Finish_Time IS NOT NULL
                AND Overall_Position IS NOT NULL
            )
        )
);


-- ============================================================
-- TRIGGERS
--
-- GO is used only where SQL Server requires CREATE TRIGGER
-- to begin a new batch.
-- ============================================================

GO


-- ============================================================
-- PAYMENT VALIDATION
--
-- Rule 1:
-- Payment Amount must match the Entry_Fee of the Race_Category.
--
-- Rule 2:
-- An Enrollment may have several payment attempts, but only
-- one payment may have a successful 'Paid' status.
-- ============================================================

CREATE TRIGGER Trigger_Validate_Payment
ON Payment
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS
    (
        SELECT 1
        FROM inserted
        INNER JOIN Enrollment
            ON Enrollment.Enrollment_ID = inserted.Enrollment_ID
        INNER JOIN Race_Category
            ON Race_Category.Category_ID = Enrollment.Category_ID
        WHERE inserted.Amount <> Race_Category.Entry_Fee
    )
    BEGIN
        RAISERROR
        (
            'Payment amount must match the race category entry fee.',
            16,
            1
        );

        ROLLBACK TRANSACTION;
        RETURN;
    END;

    IF EXISTS
    (
        SELECT Payment.Enrollment_ID
        FROM Payment
        INNER JOIN
        (
            SELECT DISTINCT Enrollment_ID
            FROM inserted
        ) AS Inserted_Enrollments
            ON Payment.Enrollment_ID =
               Inserted_Enrollments.Enrollment_ID
        WHERE Payment.Payment_Status = 'Paid'
        GROUP BY Payment.Enrollment_ID
        HAVING COUNT(*) > 1
    )
    BEGIN
        RAISERROR
        (
            'An enrollment can only have one successful Paid payment.',
            16,
            1
        );

        ROLLBACK TRANSACTION;
        RETURN;
    END;
END;
GO


-- ============================================================
-- ENROLLMENT CATEGORY CAPACITY
--
-- Prevents a category from going above Max_Participants and
-- keeps Current_Participants equal to the number of active
-- Enrollment records.
--
-- Cancelled enrollments do not use a category place.
-- ============================================================

CREATE TRIGGER Trigger_Enrollment_Category_Capacity
ON Enrollment
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Affected_Categories TABLE
    (
        Category_ID INT PRIMARY KEY
    );

    INSERT INTO @Affected_Categories (Category_ID)
    SELECT Category_ID
    FROM inserted

    UNION

    SELECT Category_ID
    FROM deleted;


    IF EXISTS
    (
        SELECT 1
        FROM @Affected_Categories AS Affected_Categories
        INNER JOIN Race_Category
            ON Race_Category.Category_ID =
               Affected_Categories.Category_ID
        WHERE
        (
            SELECT COUNT(*)
            FROM Enrollment
            WHERE Enrollment.Category_ID =
                  Race_Category.Category_ID
              AND Enrollment.Enrollment_Status <> 'Cancelled'
        ) > Race_Category.Max_Participants
    )
    BEGIN
        RAISERROR
        (
            'This race category has reached its maximum participant capacity.',
            16,
            1
        );

        ROLLBACK TRANSACTION;
        RETURN;
    END;


    UPDATE Race_Category
    SET Current_Participants =
    (
        SELECT COUNT(*)
        FROM Enrollment
        WHERE Enrollment.Category_ID =
              Race_Category.Category_ID
          AND Enrollment.Enrollment_Status <> 'Cancelled'
    )
    FROM Race_Category
    INNER JOIN @Affected_Categories AS Affected_Categories
        ON Race_Category.Category_ID =
           Affected_Categories.Category_ID;
END;
GO


-- ============================================================
-- SAMPLE DATA
--
-- Section C requires at minimum:
-- 2 Organisers
-- 2 Participants
-- 3 Events
-- Categories for every Event
-- Sample Enrollments
-- ============================================================


-- ============================================================
-- ORGANISERS
-- ============================================================

INSERT INTO Organiser
(
    Organiser_Name,
    Email,
    Phone_Number
)
VALUES
(
    'Durban Road Runners Club',
    'information@durbanroadrunners.co.za',
    '0315550101'
),
(
    'KwaZulu-Natal Athletics Events',
    'events@kwazulunatalathletics.co.za',
    '0315550102'
);


-- ============================================================
-- EVENTS
-- ============================================================

INSERT INTO [Event]
(
    Organiser_ID,
    Event_Name,
    [Description],
    Event_Date,
    Location,
    Event_Type,
    [Status],
    Closing_Date
)
VALUES
(
    1,
    'Durban Spring Road Running Festival 2026',
    'A community road running festival held along the Durban beachfront.',
    '2026-09-20',
    'Durban Promenade, Durban',
    'Run',
    'Open',
    '2026-09-15'
),
(
    1,
    'Umhlanga Coastal Running Challenge 2026',
    'A coastal running event offering several race distances.',
    '2026-10-18',
    'Umhlanga, KwaZulu-Natal',
    'Run',
    'Open',
    '2026-10-12'
),
(
    2,
    'KwaZulu-Natal Heritage Run and Walk 2026',
    'A heritage event offering running and walking race categories.',
    '2026-11-08',
    'Pietermaritzburg, KwaZulu-Natal',
    'Walk',
    'Planned',
    '2026-11-01'
);


-- ============================================================
-- RACE CATEGORIES
-- Each Event has at least one Race_Category.
-- ============================================================

INSERT INTO Race_Category
(
    Event_ID,
    Category_Name,
    Distance_KM,
    Entry_Fee,
    Max_Participants
)
VALUES
(
    1,
    'Five Kilometre Fun Run',
    5.00,
    100.00,
    300
),
(
    1,
    'Ten Kilometre Road Race',
    10.00,
    180.00,
    250
),
(
    2,
    'Five Kilometre Coastal Run',
    5.00,
    120.00,
    200
),
(
    2,
    'Twenty-One Kilometre Half Marathon',
    21.10,
    280.00,
    180
),
(
    3,
    'Five Kilometre Heritage Walk',
    5.00,
    100.00,
    300
),
(
    3,
    'Ten Kilometre Heritage Run',
    10.00,
    180.00,
    250
);


-- ============================================================
-- PARTICIPANTS
-- ============================================================

INSERT INTO Participant
(
    First_Name,
    Last_Name,
    Date_Of_Birth,
    Gender,
    Email,
    Phone_Number
)
VALUES
(
    'Sibusiso Thando',
    'Dlamini',
    '2001-05-14',
    'Male',
    'sibusiso.dlamini@example.com',
    '0825550101'
),
(
    'Amahle Nosipho',
    'Mthembu',
    '2003-09-22',
    'Female',
    'amahle.mthembu@example.com',
    '0835550102'
),
(
    'Liam Jonathan',
    'Naidoo',
    '1999-02-11',
    'Male',
    'liam.naidoo@example.com',
    '0845550103'
);


-- ============================================================
-- ENROLLMENTS
--
-- The server/API generates Race_Number when an enrollment
-- is created.
-- ============================================================

INSERT INTO Enrollment
(
    Participant_ID,
    Category_ID,
    Enrollment_Date,
    Race_Number,
    Enrollment_Status
)
VALUES
(
    1,
    1,
    '2026-09-02',
    'DURBAN-FIVE-001',
    'Confirmed'
),
(
    2,
    2,
    '2026-09-02',
    'DURBAN-TEN-001',
    'Confirmed'
),
(
    3,
    4,
    '2026-09-02',
    'UMHLANGA-HALF-001',
    'Confirmed'
),
(
    1,
    5,
    '2026-09-02',
    'HERITAGE-FIVE-001',
    'Pending'
);


-- ============================================================
-- PAYMENTS
-- ============================================================

INSERT INTO Payment
(
    Enrollment_ID,
    Amount,
    Payment_Date,
    Payment_Method,
    Payment_Status
)
VALUES
(
    1,
    100.00,
    '2026-09-02',
    'Debit Card',
    'Paid'
),
(
    2,
    180.00,
    '2026-09-02',
    'Electronic Funds Transfer',
    'Paid'
),
(
    3,
    280.00,
    '2026-09-02',
    'Credit Card',
    'Paid'
),
(
    4,
    100.00,
    '2026-09-02',
    'Debit Card',
    'Pending'
);


-- ============================================================
-- RACE RESULTS
-- ============================================================

INSERT INTO Race_Result
(
    Enrollment_ID,
    Start_Time,
    Finish_Time,
    Overall_Position,
    Result_Status
)
VALUES
(
    1,
    '2026-09-20 07:00:00',
    '2026-09-20 07:28:35',
    12,
    'Completed'
),
(
    2,
    '2026-09-20 07:15:00',
    '2026-09-20 08:05:42',
    18,
    'Completed'
);


-- ============================================================
-- CHECK THE DATA
-- ============================================================

SELECT * FROM Organiser;
SELECT * FROM [Event];
SELECT * FROM Race_Category;
SELECT * FROM Participant;
SELECT * FROM Enrollment;
SELECT * FROM Payment;
SELECT * FROM Race_Result;


-- ============================================================
-- RACE RESULT REPORT
--
-- Completion_Time is calculated rather than stored.
-- ============================================================

SELECT
    Race_Result.Result_ID,
    Enrollment.Race_Number,
    Participant.First_Name,
    Participant.Last_Name,
    Race_Category.Category_Name,
    Race_Result.Start_Time,
    Race_Result.Finish_Time,
    DATEDIFF
    (
        SECOND,
        Race_Result.Start_Time,
        Race_Result.Finish_Time
    ) AS Completion_Time_Seconds,
    Race_Result.Overall_Position,
    Race_Result.Result_Status

FROM Race_Result

INNER JOIN Enrollment
    ON Race_Result.Enrollment_ID =
       Enrollment.Enrollment_ID

INNER JOIN Participant
    ON Enrollment.Participant_ID =
       Participant.Participant_ID

INNER JOIN Race_Category
    ON Enrollment.Category_ID =
       Race_Category.Category_ID

ORDER BY Race_Result.Overall_Position;


-- ============================================================
-- END OF FINAL SCRIPT
-- ============================================================
