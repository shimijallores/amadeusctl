# Copilot Instructions for amadeusctl

## Project Overview

- **amadeusctl** is a Bash-based control script for interacting with an Amadeus-like GDS (Global Distribution System) using a MySQL backend.
- The main entry point is `flightctl.sh`, which provides a CLI for flight search, booking, and ticketing operations.
- The database schema is defined in `database.sql` and includes tables for aircraft, airlines, airports, users, seats, and flight schedules.

## Key Workflows

- **Start the CLI:** Run `bash flightctl.sh` from the project root.
- **Login:** Uses MySQL `users` table for authentication. Default users may be found in the `database.sql` dump.
- **Flight Search:** `AN <date> <origin> <dest> <airline>` (e.g., `AN Oct10 JFK LHR DLA`) — search for flights by date, origin, destination, and airline.
- **Seat Selection:** `SS<row><class><seats>` (e.g., `SS2Y2`) — select seats after a search.
- **Passenger Details:** `NM<num> Surname/First/Title ...` — enter passenger names after seat selection.
- **Agency/Customer:** `AP <number>` — enter agency and customer numbers after NM.
- **Quotation:** `FQD <origin> <dest> [R] [date]` (e.g., `FQD JFK LHR R 25NOV`) — get fare quotes.
- **Void Ticket:** `TKV <ticket id>` — void (cancel) an unpaid ticket by ticket id.
- **Refund Ticket:** `RFND <ticket id>` — refund a paid ticket by ticket id.
- **Passenger List:** `DS <carrier_code> <date>` (e.g., `DS DLA01 25NOV`) — show passenger list for a flight.
- **Logout:** `QUIT` — end the session.

## Data Flow & Structure

- All business logic is in `flightctl.sh`.
- The script interacts directly with MySQL using CLI commands and expects the schema in `database.sql`.
- State is managed via shell variables (e.g., `LAST_QUERY_RESULT`, `WAITING_FOR_NM`).
- No external dependencies beyond Bash and MySQL client.

## Conventions & Patterns

- **Commands mimic Amadeus GDS syntax** (e.g., `AN`, `SS`, `NM`, `AP`, `FQD`, `TKV`, `RFND`, `DS`).
- **Date formats:**
  - `AN` expects `MonthDD` (e.g., `Oct10`).
  - `FQD` expects `DDMON` (e.g., `15DEC`).
- **Class codes:** `F` (First), `C` (Business), `Y` (Economy).
- **All user input is interactive**; no batch or API mode.
- **Color-coded output** for user feedback.

## Integration Points

- **MySQL:** All data is persisted in a MySQL database. Update `flightctl.sh` variables to match your environment.
- **No external APIs** or services are called.

## Examples

- Search: `AN Oct10 JFK LHR DLA`
- Book: `SS2Y2` → `NM2 Smith/John/MR Doe/Jane/MS` → `AP 12345` → `AP 67890`
- Quote: `FQD JFK LHR R 25NOV`
- Void: `TKV TKT-100` (void ticket TKT-100 if unpaid)
- Refund: `RFND TKT-100` (refund ticket TKT-100 if paid)
- Passenger List: `DS DLA01 25NOV` (show passenger list for carrier DLA01 on Nov 25)

## Reference Files

- `flightctl.sh`: Main logic and workflow
- `database.sql`: Schema and sample data
- `README.md`: Basic usage examples

---

For new features, follow the GDS-style command pattern and update both the script and schema as needed. If unclear, ask for clarification on business rules or workflow details.
