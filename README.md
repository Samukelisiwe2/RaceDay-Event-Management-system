# RaceDay-Event-Management-system
Youtube link - https://youtu.be/k1OeVnKzbDQ

 <img width="940" height="448" alt="image" src="https://github.com/user-attachments/assets/53237bf4-a255-438b-ad80-277cc09d7400" />


## Project Overview

The RaceDay Event Management System is a role-based system designed to manage running, walking and cycling events.

The system supports two main user roles: **Organiser** and **Participant**.

Organisers are responsible for creating and managing events, defining race categories, viewing event enrolments and capturing race results.

Participants are able to register, log in, view available events and categories, enrol in events, make payments and view their own race results.

The project includes an ERD, API endpoint plan and SQL Server database script that are designed to work together and represent the RaceDay system.

---

## User Roles

### Organiser

The Organiser can:

- Register and log in
- View and update their own profile
- Create events
- Update events
- Delete events
- Create age or distance categories for events
- Update categories
- Delete categories
- View participant enrolments for their events
- Capture participant race results
- View event results
- View payment information related to their events

---

### Participant

The Participant can:

- Register and log in
- View and update their own profile
- View available events
- View event details
- View available race categories
- Enrol in an event by selecting a category
- View their own enrolments
- Make payments for enrolments
- View their payment status
- View their own race results

---

## Main System Features

The RaceDay system includes the following functionality:

- User authentication
- Role-based access
- User profile management
- Event management
- Age and distance race categories
- Event enrolments
- Unique race numbers
- Payment management
- Race results
- Finishing positions
- Category capacity limits
- Prevention of duplicate enrolments
- Prevention of multiple successful payments for the same enrolment

---

## Database

The database was created using **Microsoft SQL Server** and is designed to be executed using **SQL Server Management Studio (SSMS)**.

The database contains the following tables:

- `Organiser`
- `Event`
- `Race_Category`
- `Participant`
- `Enrollment`
- `Payment`
- `Race_Result`

The SQL script includes:

- Primary keys
- Foreign keys
- `NOT NULL` constraints
- `UNIQUE` constraints
- `DEFAULT` values
- `CHECK` constraints
- Sample data
- Business-rule validation

The sample data includes at least:

- 2 Organisers
- 2 Participants
- 3 Events
- Categories for each Event
- Sample Enrolments

---

## Project Documentation

The required planning documents are stored inside the `/docs` folder.

```text
docs/
├── RaceDay_ERD(1).png
├── RaceDay_API_Endpoint_Plan.pdf
└── RaceDay_Database.sql

