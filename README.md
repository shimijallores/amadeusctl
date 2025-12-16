# amadeusctl

Simple Bash CLI for Amadeus-like GDS operations using MySQL.

## Available Commands

- `AN <date> <origin> <dest> <airline>`  
  Search flights (date: MonthDD, e.g., Oct10)
- `SS<row><class><seats>`  
  Select seats after a search (e.g., SS2Y2)
- `NM<num> Surname/First/Title ...`  
  Enter passenger names (after SS)
- `AP <number>`  
  Enter agency number, then customer number (after NM)
- `FQD <origin> <dest> [R] [date]`  
  Get fare quote (date: DDMON, e.g., 15DEC)
- `QUIT`  
  Logout
