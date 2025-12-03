#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' 

# UPDATE THESE VARIABLES
MYSQL_PATH="mysql"
DATABASE_HOST=127.0.0.1
DATABASE_PORT=3306
DATABASE_USERNAME=root
DATABASE_NAME=amadeus
DATABASE_PASSWORD=

LAST_QUERY_RESULT=""
LAST_OCCUPIED_SEATS=""

LOGGED_IN_USER=""

# State variables for seat booking process
WAITING_FOR_NM=false
WAITING_FOR_AGENCY=false
WAITING_FOR_CUSTOMER=false
SELECTED_FLIGHT_NO=""
SELECTED_CLASS=""
SELECTED_NUM_SEATS=""
SELECTED_SEAT_IDS=""

# Function to print colored text
print_color() {
    echo -e "${1}${2}${NC}"
}

# Function to print header
print_header() {
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}       Flight Control System${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo ""
}

print_header

# Login process
while [ -z "$LOGGED_IN_USER" ]; do
    read -p "Username: " username
    read -s -p "Password: " password
    echo ""
    result=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT username FROM users WHERE username = '$username' AND password = '$password';")
    if [ -n "$result" ]; then
        LOGGED_IN_USER="$result"
        print_color $GREEN "Login successful. Welcome, $LOGGED_IN_USER!"
    else
        print_color $RED "Invalid username or password."
    fi
done

while true; do
    # Read user input
    echo -e "${YELLOW}Available commands:${NC}"
    echo -e "  ${WHITE}AN <date> <origin> <dest> <airline>${NC} - Search flights (date format: MonthDD, e.g., Oct10)"
    echo -e "  ${WHITE}SS<row><class><seats>${NC} - Select seats"
    echo -e "  ${WHITE}NM<num> <passengers>${NC} - Enter passenger details (after SS)"
    echo -e "  ${WHITE}AP <number>${NC} - Enter agency/customer number (after NM)"
    echo -e "  ${WHITE}QUIT${NC} - Logout the current user"
    echo ""
    read -p "$(echo -e ${GREEN}"[$LOGGED_IN_USER] Enter command: "${NC})" flight_command param1 origin_code destination_code airline_iata

    # Search for flight schedules
    if [ "${flight_command^^}" = "AN" ]; then

        # Validate departure date format (MonthDD)
        if [[ ! $param1 =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
            print_color $RED "Error: Departure date must be in MonthDD format (e.g., Oct10 for October 10)."
            continue
        fi

        # Extract month and day
        month_str=${param1:0:3}
        DAY=${param1:3:2}

        if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
            print_color $RED "Error: Invalid date. Please check the month abbreviation and day."
            continue
        fi

        # Get airport names
        origin_name=$(
            $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" \
            -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" \
            "$DATABASE_NAME" -N -B -e \
            "SELECT airport_name FROM airports WHERE iata = '${origin_code}' LIMIT 1;"
        )

        print_color $BLUE "Origin: $origin_name"

        destination_name=$(
            $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" \
            -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" \
            "$DATABASE_NAME" -N -B -e \
            "SELECT airport_name FROM airports WHERE iata = '${destination_code}' LIMIT 1;"
        )

        print_color $BLUE "Destination: $destination_name"

        QUERY="
            SELECT 
                fs.date_departure AS 'Date Departure',
                fs.time_departure AS 'Time',
                air.airline AS 'Airline',
                craft.model AS 'Aircraft',
                fs.id AS 'Flight No.'
            FROM flight_schedules fs
            JOIN flight_routes fr ON fs.flight_route_id = fr.id   
            JOIN airports a_orig ON a_orig.id = fr.origin_airport_id
            JOIN airports a_dest ON a_dest.id = fr.destination_airport_id
            JOIN airlines air ON fr.airline_id = air.id
            JOIN aircraft craft ON craft.id = fs.aircraft_id
            WHERE fs.date_departure = '${FORMATTED_DATE}'
              AND a_orig.iata = '${origin_code}'
              AND a_dest.iata = '${destination_code}'
              AND air.iata = '${airline_iata}'
        "

        RESULT=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" \
            -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" \
            "$DATABASE_NAME" -e "$QUERY")

        echo ""
        print_color $YELLOW "Flight Results:"
        echo "$RESULT" | column -t -s $'\t'
        echo ""

        if [ $(echo "$RESULT" | wc -l) -gt 1 ]; then
            LAST_QUERY_RESULT="$RESULT"
        fi
        
    # Select a flight schedule, class, and number of seats
    elif [[ "${flight_command^^}" =~ ^SS ]]; then
        if [ -z "$LAST_QUERY_RESULT" ]; then
            print_color $RED "No previous query results available."
        else
            if [[ $flight_command =~ ^SS([0-9]+)([A-Z])([0-9]+)$ ]]; then
                row=${BASH_REMATCH[1]}
                class=${BASH_REMATCH[2]}
                num_seats=${BASH_REMATCH[3]}
            else
                print_color $RED "Invalid format. Use SS<row><class><num_seats> e.g. SS2Y2"
                continue
            fi

            NUM_DATA_ROWS=$(( $(echo "$LAST_QUERY_RESULT" | wc -l) - 1 ))
            if (( row < 1 || row > NUM_DATA_ROWS )); then
                print_color $RED "Invalid row number. Please enter a number between 1 and $NUM_DATA_ROWS."
                continue
            fi

            if [[ ! $class =~ ^[FCY]$ ]]; then
                print_color $RED "Invalid class. Use F, C, or Y."
                continue
            fi

            ROW=$(echo "$LAST_QUERY_RESULT" | tail -n +2 | sed -n "${row}p")
            flight_no=$(echo "$ROW" | awk -F'\t' '{print $5}')

            available_count=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT COUNT(*) FROM seats WHERE flight_schedule_id = $flight_no AND class = '$class' AND status = 'available';")

            if (( available_count < num_seats )); then
                print_color $RED "Not enough available seats in class $class. Available: $available_count"
                continue
            fi

            # Get available seats
            available_seats=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id FROM seats WHERE flight_schedule_id = $flight_no AND class = '$class' AND status = 'available' ORDER BY id LIMIT $num_seats;")
            seat_ids=($available_seats)

            # Set state for passenger input
            WAITING_FOR_NM=true
            SELECTED_FLIGHT_NO=$flight_no
            SELECTED_CLASS=$class
            SELECTED_NUM_SEATS=$num_seats
            SELECTED_SEAT_IDS="${seat_ids[*]}"

            print_color $GREEN "Seats selected. Please enter passenger details using NM$num_seats command."
        fi

    # Add names for the passengers
    elif [[ "${flight_command^^}" =~ ^NM ]]; then
        if [ "$WAITING_FOR_NM" = true ]; then
            # Extract number from NM command 
            if [[ $flight_command =~ ^NM([0-9]+)$ ]]; then
                nm_num=${BASH_REMATCH[1]}
                if [ "$nm_num" != "$SELECTED_NUM_SEATS" ]; then
                    print_color $RED "NM number ($nm_num) does not match selected seats ($SELECTED_NUM_SEATS)."
                    continue
                fi
            else
                print_color $RED "Invalid NM format. Use NM<num> followed by passenger details."
                continue
            fi

            passenger_input="$param1 $origin_code $destination_code $airline_iata"
            passengers=($passenger_input)
            if [ ${#passengers[@]} -ne $SELECTED_NUM_SEATS ]; then
                print_color $RED "Number of passengers does not match the number of seats ($SELECTED_NUM_SEATS)."
                continue
            fi

            ticket_nums=()
            names=()
            invalid=0
            for p in "${passengers[@]}"; do
                if [[ $p =~ ^([^/]+)/([^/]+)/([^/]+)$ ]]; then
                    lastname=${BASH_REMATCH[1]}
                    firstname=${BASH_REMATCH[2]}
                    title=${BASH_REMATCH[3]}
                    name="$lastname $firstname $title"
                    ticket_num=$(openssl rand -base64 10 | tr -d "=+/" | cut -c1-10)
                    ticket_nums+=("$ticket_num")
                    names+=("$name")
                else
                    print_color $RED "Invalid passenger format: $p. Use Lastname/Firstname/Title"
                    invalid=1
                    break
                fi
            done
            if [ $invalid -eq 1 ]; then
                continue
            fi

            seat_ids=($SELECTED_SEAT_IDS)

            for i in "${!names[@]}"; do
                sid=${seat_ids[$i]}
                ticket_num=${ticket_nums[$i]}
                name=${names[$i]}
                $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "UPDATE seats SET status='occupied', ticket_id='$ticket_num', customer_name='$name' WHERE id=$sid;"
            done

            LAST_OCCUPIED_SEATS="$SELECTED_SEAT_IDS"

            print_color $GREEN "Tickets sold successfully for $SELECTED_NUM_SEATS seats in class $SELECTED_CLASS."
            for i in "${!names[@]}"; do
                print_color $CYAN "Ticket for ${names[$i]}: ${ticket_nums[$i]}"
            done

            WAITING_FOR_NM=false
            WAITING_FOR_AGENCY=true
            print_color $GREEN "Please enter agency number using AP command."
        else
            print_color $RED "No seat selection in progress. Use SS command first."
        fi

    # Add contact information
    elif [ "${flight_command^^}" = "AP" ]; then
        # Add agency number
        if [ "$WAITING_FOR_AGENCY" = true ]; then
            agency_number=$param1
            if [[ ! $agency_number =~ ^[0-9]+$ ]]; then
                print_color $RED "Invalid agency number. Must be digits."
                continue
            else
                for sid in $LAST_OCCUPIED_SEATS; do
                    $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "UPDATE seats SET agency_number='$agency_number' WHERE id=$sid;"
                done
                print_color $GREEN "Agency number updated."
                WAITING_FOR_AGENCY=false
                WAITING_FOR_CUSTOMER=true
                print_color $GREEN "Please enter customer number using AP command."
            fi
        # Add customer/s number
        elif [ "$WAITING_FOR_CUSTOMER" = true ]; then
            customer_number=$param1
            if [[ ! $customer_number =~ ^[0-9]+$ ]]; then
                print_color $RED "Invalid customer number. Must be digits."
                continue
            else
                for sid in $LAST_OCCUPIED_SEATS; do
                    $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "UPDATE seats SET customer_number='$customer_number' WHERE id=$sid;"
                done
                print_color $GREEN "Customer number updated."
                WAITING_FOR_CUSTOMER=false
                # Reset all state
                SELECTED_FLIGHT_NO=""
                SELECTED_CLASS=""
                SELECTED_NUM_SEATS=""
                SELECTED_SEAT_IDS=""
                LAST_OCCUPIED_SEATS=""
            fi
        else
            print_color $RED "No booking in progress. Complete NM and agency steps first."
        fi
    # Logout the user
    elif [ "${flight_command^^}" = "QUIT" ]; then
        print_color $GREEN "Logged out successfully."
        LOGGED_IN_USER=""
        break
    else
        print_color $RED "Unknown command!"
    fi
    echo ""
done
