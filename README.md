# amadeusctl

Simple Bash CLI for Amadeus-like GDS operations using MySQL.

## Table of Contents

- [Description](#description)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Usage](#usage)
- [Available Commands](#available-commands)
- [Examples](#examples)
- [License](#license)

## Description

`amadeusctl` is a lightweight Bash-based command-line tool that simulates Amadeus GDS operations for flight management, ticketing, and passenger handling, using a MySQL backend.

## Prerequisites

- Bash shell (Linux, macOS, or Windows with WSL/Git Bash)
- MySQL server
- Basic knowledge of airline reservation systems

## Installation

1. Clone or download this repository.
2. Ensure `flightctl.sh` is executable:
   ```sh
   chmod +x flightctl.sh
   ```
3. Set up the MySQL database using `database.sql`:
   ```sh
   mysql -u <user> -p <database> < database.sql
   ```

## Usage

Run the CLI:

```sh
./flightctl.sh
```

## Available Commands

- `AN <date> <origin> <dest> <airline>`  
  Search flights (date: MonthDD, e.g., Oct10)
- `SS<row><class><seats>`  
  Select seats after a search (e.g., SS2Y2)
- `NM<num> Surname/First/Title ...`  
  Enter passenger names
- `AP <number>`  
  Enter agency number, then customer number
- `FQD <origin> <dest> [R] [date]`  
  Get fare quote (e.g., FQD JFK LHR R 25NOV)
- `TKV <ticket id>`  
  Void (cancel) an unpaid ticket by ticket id (e.g., TKV TKT-101)
- `RFND <ticket id>`  
  Refund a paid ticket by ticket id (e.g., RFND 9SIvMzLWge)
- `DS <carrier_code> <date>`  
  Show passenger list for a flight (e.g., DS DLA01 25NOV)
- `SSR BAGO <ticket_id> <weight> <pieces>`  
  Add baggage for a ticket (e.g., SSR BAGO TKT-100 30K 2P)
- `QUIT`  
  Logout

## Examples

**Ticket selling:**

```sh
AN JFK LHR DLA
SS1F1
NM Surname/FirstName/Honorific
AP <agency number>
AP <customer number>
```

**Fare quote (FQD) command variations:**

- `FQD JFK LHR`
- `FQD JFK LHR R`
- `FQD JFK LHR 30NOV`
- `FQD JFK LHR R 25NOV`

## License

MIT License (or specify your license here)
