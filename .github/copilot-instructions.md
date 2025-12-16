# Copilot Instructions for amadeusctl

## Project Overview

- **amadeusctl** is a Bash-based control script for interacting with an Amadeus-like GDS (Global Distribution System) using a MySQL backend.
- The main entry point is `flightctl.sh`, which provides a CLI for flight search, booking, and ticketing operations.
- The database schema is defined in `database.sql` and includes tables for aircraft, airlines, airports, users, seats, and flight schedules.

## Key Workflows

- **Start the CLI:** Run `bash flightctl.sh` from the project root.
- **Login:** Uses MySQL `users` table for authentication. Default users may be found in the `database.sql` dump.
- **Flight Search:** Use the `AN` command (e.g., `AN Oct10 JFK LHR DLA`) to search for flights by date, origin, destination, and airline.
- **Seat Selection:** Use the `SS<row><class><seats>` command after a search (e.g., `SS2Y2`).
- **Passenger Details:** Use the `NM<num> Surname/First/Title ...` command to enter passenger names.
- **Agency/Customer:** Use the `AP <number>` command twice to enter agency and customer numbers.
- **Quotation:** Use the `FQD` command (e.g., `FQD JFK LHR R 25NOV`) for fare quotes.
- **Logout:** Use `QUIT` to end the session.

## Data Flow & Structure

- All business logic is in `flightctl.sh`.
- The script interacts directly with MySQL using CLI commands and expects the schema in `database.sql`.
- State is managed via shell variables (e.g., `LAST_QUERY_RESULT`, `WAITING_FOR_NM`).
- No external dependencies beyond Bash and MySQL client.

## Conventions & Patterns

- **Commands mimic Amadeus GDS syntax** (e.g., `AN`, `SS`, `NM`, `AP`, `FQD`).
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

## Reference Files

- `flightctl.sh`: Main logic and workflow
- `database.sql`: Schema and sample data
- `README.md`: Basic usage examples

---

For new features, follow the GDS-style command pattern and update both the script and schema as needed. If unclear, ask for clarification on business rules or workflow details.
