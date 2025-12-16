# amadeusctl

Simple Bash CLI for Amadeus-like GDS operations using MySQL.

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
  Get fare quote (ex: )
- `TKV <ticket id>`  
  Void (cancel) an unpaid ticket by ticket id (ex: )
- `RFND <ticket id>`  
  Refund a paid ticket by ticket id (ex: )
- `DS <carrier_code> <date>`  
  Show passenger list for a flight (ex: DS DLA01 25NOV)
- `QUIT`  
  Logout
