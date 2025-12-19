# amadeusctl

Simple Bash CLI for Amadeus-like GDS operations using MySQL.

## Description

`amadeusctl` is a lightweight Bash-based command-line tool that simulates Amadeus GDS operations for flight management, ticketing, and passenger handling, using a MySQL backend.

## Installation & Usage

1. Clone or download this repository.
2. Ensure `flightctl.sh` is executable:
   ```sh
   chmod +x flightctl.sh
   ```
3. Update the mysql configuration in the flightctl.sh
4. Run the CLI:

```sh
./flightctl.sh
```

## Demonstration

**Search flights command (AN):**

1. `AN` availabity search
   Description: Search for available flights between airports
   Format: `AN <origin> <destination> <date>`
   Example: `AN JFK LHR NOV25`

2. `AN` with class filter
   Description: Search flights and display specific class pricing
   Format: `AN <origin> <destination> <date> <class>`
   Classes: `f (First), c (Business), y (Economy)`
   Example:`AN JFK LHR NOV25 f`
   Example: `AN JFK LHR NOV25 c`
   Example: `AN JFK LHR NOV25 y`

3. `AN` with airline filter
   Description: Search flights by specific airline
   Format: `AN <date> <origin> <destination> <airline>`
   Example: `AN NOV25 JFK LHR DLA`

4. `AN` with date range
   Description: Search flights within a date range
   Format: `AN <origin> <destination> <date_from> <date_to>`
   Example: `AN JFK LHR NOV25 DEC25`

5. `AN` multi city
   Description: Search for multiple flight segments
   Format: `AN <origin1> <dest1> <date1> <origin2> <dest2> <date2>`
   Example: `AN JFK LHR NOV25 LHR HND DEC02`

**Ticket ordering command (AN, SS, NM, AP agency, AP customer):**

Example Workflow (Full ticket ordering):

1. Fetch Flights
   Format: `AN <date> <origin> <destination> <airline>`
   Example:`AN NOV25 JFK LHR DLA`

2. Select flight, class, and seat
   Format: `SS<row><class><seats>`
   Example: `SS1C1`

3. Input customer name/s
   Format: `NM<num> Surname/First/Title ...`
   Example: `NM1 Jallores/Shimi/Mr`

4. Enter agency number
   Format: `AP <agency number>`
   Example (Agency):`AP 09123456789`

5. Enter customer number
   Format: `AP <customer number>`
   Example: `AP 09123456789`

**Fare quote command (FQD):**

1. FQD One Way
   Format: `FQD <origin> <destination>`
   Example: `FQD JFK LHR`

2. FQD Round Trip
   Format: `FQD <origin> <destination> [R]`
   Example: `FQD JFK LHR R`

3. FQD One Way (with date)
   Format: `FQD <origin> <destination> [date]`
   Example: `FQD JFK LHR 26NOV`

4. FQD Round Trip (with date)
   Format: `FQD <origin> <destination> [R] [date]`
   Example: `FQD JFK LHR R 25NOV`

**Void Command (TKV):**
Description: Void (cancel) an unpaid ticket by ticket id
Format: `TKV <ticket_id`
Example: `TKV TKT-101`

**Refund Command (RFND):**
Description: Refund a paid ticket by ticket id
Format: `RFND <ticket id>`
Example: `RFND 9SIvMzLWge`

**List Passengers Command (DS):**
Description: Show passenger list for a flight
Format: `DS <carrier_code> <date>`
Example: `DS DLA01 25NOV`

**Baggage Command (SSR):**
Description: Add baggage for a ticket
Format: `SSR BAGO <ticket_id> <weight> <pieces>`  
Example: `SSR BAGO TKT-100 30K 2P`

**Signout/Logout Command (SO):**
Description: Log out of the session
Command: `SO`
