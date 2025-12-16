# amadeusctl

Simple Bash CLI for Amadeus-like GDS operations using MySQL.

## Available Commands

<<<<<<< HEAD
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
=======
Ticket selling feature.

1. AN JFK LHR DLA
2. SS1F1
3. NM Surname/FirstName/Honorific
4. AP agency number
5. AP customer number

"FQD" command demo.

Variation 1: FQD JFK LHR
Variation 2: FQD JFK LHR R
Variation 3: FQD JFK LHR 30NOV
Variation 4: FQD JFK LHR R 25NOV
>>>>>>> 1291a76a1b50ef3fafa5caffe7fc683c7daff0ea
