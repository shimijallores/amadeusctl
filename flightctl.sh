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
MYSQL_PATH="mysql" # /usr/bin/mysql for my lappy
DATABASE_HOST=127.0.0.1
DATABASE_PORT=3306
DATABASE_USERNAME=root
DATABASE_NAME=amadeus
DATABASE_PASSWORD="" # shimishimi for my lappy

LAST_QUERY_RESULT=""
LAST_OCCUPIED_SEATS=""

LOGGED_IN_USER=""

WAITING_FOR_NM=false
WAITING_FOR_AGENCY=false
WAITING_FOR_CUSTOMER=false
SELECTED_FLIGHT_NO=""
SELECTED_CLASS=""
SELECTED_NUM_SEATS=""
SELECTED_SEAT_IDS=""

# Print colored text
print_color() {
    echo -e "${1}${2}${NC}"
}

# Print header
print_header() {
    echo -e "${CYAN}=======================================${NC}"
    echo -e "${CYAN}       Flight Control System${NC}"
    echo -e "${CYAN}=======================================${NC}"
    echo ""
}

# Print available commands
print_commands() {
    echo -e "${YELLOW}Available commands:${NC}"
    echo -e "  ${WHITE}AN <date> <origin> <dest> <airline>${NC} - Search flights"
    echo -e "  ${WHITE}SS<row><class><seats>${NC} - Select seats"
    echo -e "  ${WHITE}NM<num> <passengers>${NC} - Enter passenger details (after SS)"
    echo -e "  ${WHITE}AP <number>${NC} - Enter agency/customer number (after NM)"
    echo -e "  ${WHITE}FQD <origin> <dest> [R] [date]${NC} - Get flight quotation"
    echo -e "  ${WHITE}TKV <ticket id>${NC} - Void (cancel) an unpaid ticket by ticket id"
    echo -e "  ${WHITE}RFND <ticket id>${NC} - Refund a paid ticket by ticket id"
    echo -e "  ${WHITE}DS <carrier_code> <date>${NC} - Show passenger list for a flight)"
    echo -e "  ${WHITE}SSR BAGO <ticket_id> <weight> <pieces>${NC} - Add baggage for a ticket"
    echo -e "  ${WHITE}HELP${NC} - Show available commands"
    echo -e "  ${WHITE}QUIT${NC} - Logout the current user"
    echo ""
}

print_header

# Login logic
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
    read -p "$(echo -e ${GREEN}"[$LOGGED_IN_USER] Enter command: "${NC})" flight_command param1 origin_code destination_code airline_iata

    if [ "${flight_command^^}" = "HELP" ]; then
        print_commands
    
    # Search for flight schedules
    elif [ "${flight_command^^}" = "AN" ]; then
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
    
    # Add Baggage command
    elif [[ "${flight_command^^}" = "SSR" && "${param1^^}" = "BAGO" ]]; then
        ssr_ticket_id="$origin_code"
        ssr_weight="$destination_code"
        ssr_pieces="$airline_iata"
        if [ -z "$ssr_ticket_id" ] || [ -z "$ssr_weight" ] || [ -z "$ssr_pieces" ]; then
            print_color $RED "Usage: SSR BAGO <ticket_id> <weight> <pieces>"
            continue
        fi
        # Parse weight
        if [[ $ssr_weight =~ ^([0-9]+)[Kk]$ ]]; then
            ssr_weight_val=${BASH_REMATCH[1]}
        else
            print_color $RED "Invalid weight format. Use e.g., 1K for 1 kilograms."
            continue
        fi
        # Parse pieces
        if [[ $ssr_pieces =~ ^([0-9]+)[Pp]$ ]]; then
            ssr_pieces_val=${BASH_REMATCH[1]}
        else
            print_color $RED "Invalid pieces format. Use e.g., 1P for 1 piece/s."
            continue
        fi
        # Get seat, flight_schedule_id, aircraft_id
        seat_row=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id, flight_schedule_id, aircraft_id FROM seats WHERE ticket_id = '$ssr_ticket_id' LIMIT 1;")
        if [ -z "$seat_row" ]; then
            print_color $RED "Ticket ID not found."
            continue
        fi
        seat_id=$(echo "$seat_row" | awk '{print $1}')
        flight_schedule_id=$(echo "$seat_row" | awk '{print $2}')
        aircraft_id=$(echo "$seat_row" | awk '{print $3}')
        if [ -z "$aircraft_id" ]; then
            # fallback: get aircraft_id from flight_schedules
            aircraft_id=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT aircraft_id FROM flight_schedules WHERE id = $flight_schedule_id LIMIT 1;")
        fi
        if [ -z "$aircraft_id" ]; then
            print_color $RED "Aircraft not found for this ticket."
            continue
        fi
        # Get aircraft payload_capacity
        payload_capacity=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT payload_capacity FROM aircraft WHERE id = $aircraft_id LIMIT 1;")
        if [ -z "$payload_capacity" ]; then
            print_color $RED "Aircraft payload capacity not found."
            continue
        fi
        # Calculate total baggage weight for this flight
        total_baggage=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT IFNULL(SUM(weight),0) FROM baggage WHERE seat_id IN (SELECT id FROM seats WHERE flight_schedule_id = $flight_schedule_id);")
        new_total=$((total_baggage + ssr_weight_val))
        if (( new_total > payload_capacity )); then
            print_color $RED "Cannot add baggage: exceeds aircraft payload capacity ($payload_capacity kg)."
            continue
        fi

        # Insert baggage row
        $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "INSERT INTO baggage (pieces, weight, seat_id, passenger_name, ticket_id) VALUES ($ssr_pieces_val, $ssr_weight_val, $seat_id, (SELECT customer_name FROM seats WHERE id = $seat_id), '$ssr_ticket_id');"
        print_color $GREEN "Baggage added: $ssr_weight_val kg, $ssr_pieces_val piece(s) for ticket $ssr_ticket_id."

    # Select flight, class, and buy plane seat
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
    # Flight quotation command
    elif [ "${flight_command^^}" = "FQD" ]; then
        fqd_origin="${param1^^}"
        fqd_dest="${origin_code^^}"
        fqd_param3="${destination_code^^}"
        fqd_param4="${airline_iata^^}"

        # Determine round_trip and date based on parameters
        round_trip_value=0
        fqd_date=""

        # Check if param3 is "R" (roundtrip) or a date
        if [ "$fqd_param3" = "R" ]; then
            round_trip_value=1
            # Check if param4 is a date
            if [ -n "$fqd_param4" ]; then
                fqd_date="$fqd_param4"
            fi
        elif [ -n "$fqd_param3" ]; then
            # param3 is a date (one-way with date)
            fqd_date="$fqd_param3"
        fi

        # Validate origin and destination
        if [ -z "$fqd_origin" ] || [ -z "$fqd_dest" ]; then
            print_color $RED "Error: FQD requires origin and destination IATA codes."
            print_color $RED "Usage: FQD <origin> <dest> [R] [date]"
            continue
        fi

        # Get origin airport ID
        origin_id=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id FROM airports WHERE iata = '$fqd_origin' LIMIT 1;")
        if [ -z "$origin_id" ]; then
            print_color $RED "Error: Origin airport '$fqd_origin' not found."
            continue
        fi

        # Get destination airport ID
        dest_id=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id FROM airports WHERE iata = '$fqd_dest' LIMIT 1;")
        if [ -z "$dest_id" ]; then
            print_color $RED "Error: Destination airport '$fqd_dest' not found."
            continue
        fi

        # Get airport names for display
        origin_airport_name=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT airport_name FROM airports WHERE id = $origin_id;")
        dest_airport_name=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT airport_name FROM airports WHERE id = $dest_id;")

        print_color $BLUE "Origin: $origin_airport_name ($fqd_origin)"
        print_color $BLUE "Destination: $dest_airport_name ($fqd_dest)"
        if [ $round_trip_value -eq 1 ]; then
            print_color $BLUE "Type: Round Trip"
        else
            print_color $BLUE "Type: One Way"
        fi

        # Build the query based on parameters
        if [ -n "$fqd_date" ]; then
            # Parse the date (format: DDMON e.g., 15DEC)
            if [[ $fqd_date =~ ^([0-9]{2})([A-Za-z]{3})$ ]]; then
                day_part=${BASH_REMATCH[1]}
                month_part=${BASH_REMATCH[2]}
                if ! FORMATTED_FQD_DATE=$(date -d "${month_part} ${day_part} 2025" +%Y-%m-%d 2>/dev/null); then
                    print_color $RED "Error: Invalid date format. Use DDMON (e.g., 15DEC)."
                    continue
                fi
                print_color $BLUE "Date: $FORMATTED_FQD_DATE"
                
                FQD_QUERY="
                    SELECT 
                        fs.id AS 'Flight ID',
                        fs.date_departure AS 'Departure Date',
                        fs.time_departure AS 'Departure Time',
                        fs.date_arrival AS 'Arrival Date',
                        fs.time_arrival AS 'Arrival Time',
                        air.airline AS 'Airline',
                        craft.model AS 'Aircraft',
                        fs.status AS 'Status',
                        fs.price_f AS 'First Class',
                        fs.price_c AS 'Business',
                        fs.price_y AS 'Economy'
                    FROM flight_schedules fs
                    JOIN flight_routes fr ON fs.flight_route_id = fr.id
                    JOIN airlines air ON fr.airline_id = air.id
                    JOIN aircraft craft ON fs.aircraft_id = craft.id
                    WHERE fr.origin_airport_id = $origin_id
                      AND fr.destination_airport_id = $dest_id
                      AND fr.round_trip = $round_trip_value
                      AND fs.date_departure = '$FORMATTED_FQD_DATE'
                    ORDER BY RAND()
                    LIMIT 1
                "
            else
                print_color $RED "Error: Invalid date format. Use DDMON (e.g., 15DEC)."
                continue
            fi
        else
            # No date filter
            FQD_QUERY="
                SELECT 
                    fs.id AS 'Flight ID',
                    fs.date_departure AS 'Departure Date',
                    fs.time_departure AS 'Departure Time',
                    fs.date_arrival AS 'Arrival Date',
                    fs.time_arrival AS 'Arrival Time',
                    air.airline AS 'Airline',
                    craft.model AS 'Aircraft',
                    fs.status AS 'Status',
                    fs.price_f AS 'First Class',
                    fs.price_c AS 'Business',
                    fs.price_y AS 'Economy'
                FROM flight_schedules fs
                JOIN flight_routes fr ON fs.flight_route_id = fr.id
                JOIN airlines air ON fr.airline_id = air.id
                JOIN aircraft craft ON fs.aircraft_id = craft.id
                WHERE fr.origin_airport_id = $origin_id
                  AND fr.destination_airport_id = $dest_id
                  AND fr.round_trip = $round_trip_value
                ORDER BY RAND()
                LIMIT 1
            "
        fi

        FQD_RESULT=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "$FQD_QUERY")

        echo ""
        if [ $(echo "$FQD_RESULT" | wc -l) -gt 1 ]; then
            print_color $YELLOW "Flight Quotation:"
            echo "$FQD_RESULT" | column -t -s $'\t'
        else
            print_color $RED "No flights found for the specified route and criteria."
        fi
    
    # Void Ticket command
    elif [ "${flight_command^^}" = "TKV" ]; then
        tkv_ticket_id="$param1"
        if [ -z "$tkv_ticket_id" ]; then
            print_color $RED "Error: TKV requires a ticket id."
            continue
        fi
        # Check if ticket exists and is unpaid
        seat_row=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id, status, is_paid FROM seats WHERE ticket_id = '$tkv_ticket_id' LIMIT 1;")
        if [ -z "$seat_row" ]; then
            print_color $RED "Ticket ID not found."
            continue
        fi
        seat_id=$(echo "$seat_row" | awk '{print $1}')
        seat_status=$(echo "$seat_row" | awk '{print $2}')
        seat_paid=$(echo "$seat_row" | awk '{print $3}')
        if [ "$seat_status" != "occupied" ]; then
            print_color $RED "Ticket is not currently booked."
            continue
        fi
        if [ "$seat_paid" = "paid" ]; then
            print_color $RED "Ticket has already been paid and cannot be voided."
            continue
        fi
        read -p "TKV[$tkv_ticket_id] confirm cancellation? [y/N]: " tkv_confirm
        if [[ ! "$tkv_confirm" =~ ^[Yy]$ ]]; then
            print_color $YELLOW "Cancellation aborted."
            continue
        fi
        $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "UPDATE seats SET status='available', customer_name=NULL, customer_number=NULL, agency_number=NULL, ticket_id=NULL, is_paid='unpaid' WHERE id=$seat_id;"
        print_color $GREEN "Ticket $tkv_ticket_id has been voided and seat is now available."
    # Refund Ticket command
    elif [ "${flight_command^^}" = "RFND" ]; then
        rfnd_ticket_id="$param1"
        if [ -z "$rfnd_ticket_id" ]; then
            print_color $RED "Error: RFND requires a ticket id."
            continue
        fi
        # Check if ticket exists and is paid
        seat_row=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id, status, is_paid, price, customer_name FROM seats WHERE ticket_id = '$rfnd_ticket_id' LIMIT 1;")
        if [ -z "$seat_row" ]; then
            print_color $RED "Ticket ID not found."
            continue
        fi
        seat_id=$(echo "$seat_row" | awk '{print $1}')
        seat_status=$(echo "$seat_row" | awk '{print $2}')
        seat_paid=$(echo "$seat_row" | awk '{print $3}')
        seat_price=$(echo "$seat_row" | awk '{print $4}')
        seat_cust=$(echo "$seat_row" | awk '{print $5}')
        if [ "$seat_paid" != "paid" ]; then
            print_color $RED "Ticket is not paid and cannot be refunded."
            continue
        fi
        if [ -z "$seat_price" ] || [ "$seat_price" = "0" ]; then
            print_color $RED "No price found for this ticket. Cannot refund."
            continue
        fi
        read -p "RFND$rfnd_ticket_id confirm refund? y/N: " rfnd_confirm
        if [[ ! "$rfnd_confirm" =~ ^[Yy]$ ]]; then
            print_color $YELLOW "Refund aborted."
            continue
        fi
        $MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -e "UPDATE seats SET status='available', customer_name=NULL, customer_number=NULL, agency_number=NULL, ticket_id=NULL, is_paid='unpaid', price=NULL WHERE id=$seat_id;"
        print_color $GREEN "₱$seat_price has been succesfully refunded to $seat_cust with a ticket of $rfnd_ticket_id"

    # Passenger List command
    elif [ "${flight_command^^}" = "DS" ]; then
        ds_carrier_code="$param1"
        ds_date="$origin_code"
        if [ -z "$ds_carrier_code" ] || [ -z "$ds_date" ]; then
            print_color $RED "Usage: DS <carrier_code> <date>"
            continue
        fi
        # Parse date (DDMON to YYYY-MM-DD)
        if [[ $ds_date =~ ^([0-9]{2})([A-Za-z]{3})$ ]]; then
            ds_day=${BASH_REMATCH[1]}
            ds_month=${BASH_REMATCH[2]}
            if ! ds_formatted_date=$(date -d "${ds_month} ${ds_day} 2025" +%Y-%m-%d 2>/dev/null); then
                print_color $RED "Invalid date format. Use DDMON (e.g., 15JUN)."
                continue
            fi
        else
            print_color $RED "Invalid date format. Use DDMON (e.g., 15JUN)."
            continue
        fi
        # Find flight_schedule id
        ds_flight_id=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT id FROM flight_schedules WHERE carrier_code = '$ds_carrier_code' AND date_departure = '$ds_formatted_date' LIMIT 1;")
        if [ -z "$ds_flight_id" ]; then
            print_color $RED "No flight found for carrier $ds_carrier_code on $ds_formatted_date."
            continue
        fi
        # Fetch passenger names
        ds_passengers=$($MYSQL_PATH -h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME" -p"$DATABASE_PASSWORD" "$DATABASE_NAME" -N -B -e "SELECT customer_name FROM seats WHERE flight_schedule_id = $ds_flight_id AND customer_name IS NOT NULL;")
        if [ -z "$ds_passengers" ]; then
            print_color $YELLOW "No passengers found for this flight."
        else
            print_color $CYAN "Passenger List for $ds_carrier_code on $ds_date:"
            echo "$ds_passengers"
        fi
        


    # Logout the user
    elif [ "${flight_command^^}" = "SO" ]; then
        print_color $GREEN "Logged out successfully."
        LOGGED_IN_USER=""
        break
    else
        print_color $RED "Unknown command!"
    fi
    echo ""
done





