#!/bin/bash

# UPDATE THESE VARIABLES WITH YOUR COMPUTERS CONFIG
MYSQL_PATH="mysql"
DATABASE_HOST=127.0.0.1
DATABASE_PORT=3306
DATABASE_USERNAME=root
DATABASE_NAME=amadeus
DATABASE_PASSWORD=""

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' 

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
    echo -e "${CYAN}       Amadeus Control System${NC}"
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

# MySQL query helper function
mysql_query() {
    local args=(-h "$DATABASE_HOST" -P "$DATABASE_PORT" -u "$DATABASE_USERNAME")
    if [ -n "$DATABASE_PASSWORD" ]; then
        args+=(-p"$DATABASE_PASSWORD")
    fi
    args+=("$DATABASE_NAME" "$@")
    "$MYSQL_PATH" "${args[@]}"
}

print_header

# Login logic
while [ -z "$LOGGED_IN_USER" ]; do
    read -p "Username: " username
    read -s -p "Password: " password
    echo ""
    result=$(mysql_query -N -B -e "SELECT username FROM users WHERE username = '$username' AND password = '$password';")
    if [ -n "$result" ]; then
        LOGGED_IN_USER="$result"
        print_color $GREEN "Login successful. Welcome, $LOGGED_IN_USER!"
    else
        print_color $RED "Invalid username or password."
    fi
done

while true; do
    read -p "$(echo -e ${GREEN}"[$LOGGED_IN_USER] Enter command: "${NC})" user_input

    # Parse command and arguments
    read -ra args <<< "$user_input"
    flight_command="${args[0]}"
    
    # Check for booking cancellation: if user runs a command other than NM, AP, HELP, SO while booking is pending
    if ([ "$WAITING_FOR_NM" = true ] || [ "$WAITING_FOR_CUSTOMER" = true ]) && \
       ! [[ "${flight_command^^}" =~ ^NM ]] && ! [[ "${flight_command^^}" =~ ^AP$ ]] && \
       [ "${flight_command^^}" != "HELP" ] && [ "${flight_command^^}" != "SO" ]; then
        
        # Cancel the booking and free up the seats
        print_color $RED "Booking cancelled - seats have been released."
        
        # Reset customer_name, customer_number, agency_number, ticket_id for the selected seats
        for seat_id in $SELECTED_SEAT_IDS; do
            mysql_query -e "UPDATE seats SET status='available', ticket_id=NULL, customer_name=NULL, customer_number=NULL, agency_number=NULL WHERE id=$seat_id;"
        done
        
        # Reset state
        WAITING_FOR_NM=false
        WAITING_FOR_AGENCY=false
        WAITING_FOR_CUSTOMER=false
        SELECTED_FLIGHT_NO=""
        SELECTED_CLASS=""
        SELECTED_NUM_SEATS=""
        SELECTED_SEAT_IDS=""
        LAST_OCCUPIED_SEATS=""
        echo ""
    fi
    
    if [ "${flight_command^^}" = "HELP" ]; then
        print_commands
    
    # Search for flight schedules - Multiple variations
    elif [ "${flight_command^^}" = "AN" ]; then
        num_args=${#args[@]}
        
        # Variation 1: AN <origin> <destination> <date> - Basic search
        if [ $num_args -eq 4 ]; then
            origin="${args[1]^^}"
            destination="${args[2]^^}"
            date_input="${args[3]}"
            
            # Validate date format (MMMDD or DDMON)
            if [[ $date_input =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                # MonthDD format
                month_str=${date_input:0:3}
                DAY=${date_input:3:2}
                if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
                    print_color $RED "Error: Invalid date. Please check the month abbreviation and day."
                    continue
                fi
            elif [[ $date_input =~ ^[0-9]{2}[A-Za-z]{3}$ ]]; then
                # DDMON format
                DAY=${date_input:0:2}
                month_str=${date_input:2:3}
                if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
                    print_color $RED "Error: Invalid date. Please check the day and month abbreviation."
                    continue
                fi
            else
                print_color $RED "Error: Date must be in MonthDD or DDMON format (e.g., Oct10 or 10OCT)."
                continue
            fi
            
            # Get airport names
            origin_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin}' LIMIT 1;")
            if [ -z "$origin_name" ]; then
                print_color $RED "Error: Origin airport '$origin' not found."
                continue
            fi
            
            destination_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination}' LIMIT 1;")
            if [ -z "$destination_name" ]; then
                print_color $RED "Error: Destination airport '$destination' not found."
                continue
            fi
            
            print_color $BLUE "Origin: $origin_name ($origin)"
            print_color $BLUE "Destination: $destination_name ($destination)"
            print_color $BLUE "Date: $FORMATTED_DATE"
            
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
                  AND a_orig.iata = '${origin}'
                  AND a_dest.iata = '${destination}'
            "
            
            RESULT=$(mysql_query -e "$QUERY")
            
            echo ""
            if [ $(echo "$RESULT" | wc -l) -gt 1 ]; then
                print_color $YELLOW "Flight Results:"
                echo "$RESULT" | column -t -s $'\t'
                LAST_QUERY_RESULT="$RESULT"
            else
                print_color $YELLOW "No flights found for this route and date."
            fi
            echo ""
        
        # Variation 2 & 3: Need to distinguish between class filter and airline filter for 5 args
        elif [ $num_args -eq 5 ]; then
            # Check if this is class filter (AN <origin> <destination> <date> <class>)
            # or airline filter (AN <date> <origin> <destination> <airline>)
            # Distinguish by checking if 4th arg is a valid class (F/C/Y) or if 2nd arg is a date format
            
            potential_date="${args[1]}"
            potential_class="${args[4]}"
            
            # If first param (after AN) looks like a date (MonthDD), treat as airline filter
            if [[ $potential_date =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                # This is Variation 3: AN <date> <origin> <destination> <airline>
                date_input="${args[1]}"
                origin="${args[2]^^}"
                destination="${args[3]^^}"
                airline="${args[4]^^}"
                
                # Validate departure date format (MonthDD)
                if [[ ! $date_input =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                    print_color $RED "Error: Departure date must be in MonthDD format (e.g., Oct10 for October 10)."
                    continue
                fi

                # Extract month and day
                month_str=${date_input:0:3}
                DAY=${date_input:3:2}

                if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
                    print_color $RED "Error: Invalid date. Please check the month abbreviation and day."
                    continue
                fi

                # Get airport names
                origin_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin}' LIMIT 1;")
                if [ -z "$origin_name" ]; then
                    print_color $RED "Error: Origin airport '$origin' not found."
                    continue
                fi

                destination_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination}' LIMIT 1;")
                if [ -z "$destination_name" ]; then
                    print_color $RED "Error: Destination airport '$destination' not found."
                    continue
                fi

                print_color $BLUE "Origin: $origin_name ($origin)"
                print_color $BLUE "Destination: $destination_name ($destination)"
                print_color $BLUE "Airline: $airline"

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
                      AND a_orig.iata = '${origin}'
                      AND a_dest.iata = '${destination}'
                      AND air.iata = '${airline}'
                "

                RESULT=$(mysql_query -e "$QUERY")

                echo ""
                if [ $(echo "$RESULT" | wc -l) -gt 1 ]; then
                    print_color $YELLOW "Flight Results:"
                    echo "$RESULT" | column -t -s $'\t'
                    LAST_QUERY_RESULT="$RESULT"
                else
                    print_color $YELLOW "No flights found for this route, date, and airline."
                fi
                echo ""
            
            # Otherwise, treat as Variation 2: AN <origin> <destination> <date> <class>
            elif [[ $potential_class =~ ^[FfCcYy]$ ]]; then
                origin="${args[1]^^}"
                destination="${args[2]^^}"
                date_input="${args[3]}"
                class="${potential_class^^}"
                
                # Validate date format (MMMDD or DDMON)
                if [[ $date_input =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                    # MonthDD format
                    month_str=${date_input:0:3}
                    DAY=${date_input:3:2}
                    if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
                        print_color $RED "Error: Invalid date. Please check the month abbreviation and day."
                        continue
                    fi
                elif [[ $date_input =~ ^[0-9]{2}[A-Za-z]{3}$ ]]; then
                    # DDMON format
                    DAY=${date_input:0:2}
                    month_str=${date_input:2:3}
                    if ! FORMATTED_DATE=$(date -d "${month_str} ${DAY} 2025" +%Y-%m-%d 2>/dev/null); then
                        print_color $RED "Error: Invalid date. Please check the day and month abbreviation."
                        continue
                    fi
                else
                    print_color $RED "Error: Date must be in MonthDD or DDMON format (e.g., Oct10 or 10OCT)."
                    continue
                fi
                
                # Get airport names
                origin_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin}' LIMIT 1;")
                if [ -z "$origin_name" ]; then
                    print_color $RED "Error: Origin airport '$origin' not found."
                    continue
                fi
                
                destination_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination}' LIMIT 1;")
                if [ -z "$destination_name" ]; then
                    print_color $RED "Error: Destination airport '$destination' not found."
                    continue
                fi
                
                # Map class code to full name and price column
                case "$class" in
                    F)
                        class_name="First Class"
                        price_column="fs.price_f"
                        ;;
                    C)
                        class_name="Business Class"
                        price_column="fs.price_c"
                        ;;
                    Y)
                        class_name="Economy Class"
                        price_column="fs.price_y"
                        ;;
                esac
                
                print_color $BLUE "Origin: $origin_name ($origin)"
                print_color $BLUE "Destination: $destination_name ($destination)"
                print_color $BLUE "Date: $FORMATTED_DATE"
                print_color $BLUE "Class: $class_name"
                
                QUERY="
                    SELECT 
                        fs.date_departure AS 'Date Departure',
                        fs.time_departure AS 'Time',
                        air.airline AS 'Airline',
                        craft.model AS 'Aircraft',
                        $price_column AS 'Price',
                        CONCAT(
                            (SELECT COUNT(*) FROM seats WHERE flight_schedule_id = fs.id AND class = '$class' AND status = 'available'),
                            '/',
                            (SELECT COUNT(*) FROM seats WHERE flight_schedule_id = fs.id AND class = '$class')
                        ) AS 'Available Seats',
                        fs.id AS 'Flight No.'
                    FROM flight_schedules fs
                    JOIN flight_routes fr ON fs.flight_route_id = fr.id   
                    JOIN airports a_orig ON a_orig.id = fr.origin_airport_id
                    JOIN airports a_dest ON a_dest.id = fr.destination_airport_id
                    JOIN airlines air ON fr.airline_id = air.id
                    JOIN aircraft craft ON craft.id = fs.aircraft_id
                    WHERE fs.date_departure = '${FORMATTED_DATE}'
                      AND a_orig.iata = '${origin}'
                      AND a_dest.iata = '${destination}'
                "
                
                RESULT=$(mysql_query -e "$QUERY")
                
                echo ""
                if [ $(echo "$RESULT" | wc -l) -gt 1 ]; then
                    print_color $YELLOW "Flight Results ($class_name):"
                    echo "$RESULT" | column -t -s $'\t'
                    LAST_QUERY_RESULT="$RESULT"
                else
                    print_color $YELLOW "No flights found for this route, date, and class."
                fi
                echo ""
            else
                # Check if this might be Variation 4: AN <origin> <destination> <date_from> <date_to> (date range)
                date_from="${args[3]}"
                date_to="${args[4]}"
                
                # Check if both look like dates
                if [[ ($date_from =~ ^[A-Za-z]{3}[0-9]{2}$ || $date_from =~ ^[0-9]{2}[A-Za-z]{3}$) && 
                      ($date_to =~ ^[A-Za-z]{3}[0-9]{2}$ || $date_to =~ ^[0-9]{2}[A-Za-z]{3}$) ]]; then
                    
                    # This is Variation 4: AN <origin> <destination> <date_from> <date_to>
                    origin="${args[1]^^}"
                    destination="${args[2]^^}"
                    
                    # Parse date_from
                    if [[ $date_from =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                        month_str_from=${date_from:0:3}
                        day_from=${date_from:3:2}
                    else
                        day_from=${date_from:0:2}
                        month_str_from=${date_from:2:3}
                    fi
                    
                    if ! FORMATTED_DATE_FROM=$(date -d "${month_str_from} ${day_from} 2025" +%Y-%m-%d 2>/dev/null); then
                        print_color $RED "Error: Invalid from-date. Please check the format."
                        continue
                    fi
                    
                    # Parse date_to
                    if [[ $date_to =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                        month_str_to=${date_to:0:3}
                        day_to=${date_to:3:2}
                    else
                        day_to=${date_to:0:2}
                        month_str_to=${date_to:2:3}
                    fi
                    
                    if ! FORMATTED_DATE_TO=$(date -d "${month_str_to} ${day_to} 2025" +%Y-%m-%d 2>/dev/null); then
                        print_color $RED "Error: Invalid to-date. Please check the format."
                        continue
                    fi
                    
                    # Validate date range
                    if [[ "$FORMATTED_DATE_FROM" > "$FORMATTED_DATE_TO" ]]; then
                        print_color $RED "Error: From-date must be before or equal to to-date."
                        continue
                    fi
                    
                    # Get airport names
                    origin_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin}' LIMIT 1;")
                    if [ -z "$origin_name" ]; then
                        print_color $RED "Error: Origin airport '$origin' not found."
                        continue
                    fi
                    
                    destination_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination}' LIMIT 1;")
                    if [ -z "$destination_name" ]; then
                        print_color $RED "Error: Destination airport '$destination' not found."
                        continue
                    fi
                    
                    print_color $BLUE "Origin: $origin_name ($origin)"
                    print_color $BLUE "Destination: $destination_name ($destination)"
                    print_color $BLUE "Date Range: $FORMATTED_DATE_FROM to $FORMATTED_DATE_TO"
                    
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
                        WHERE fs.date_departure BETWEEN '${FORMATTED_DATE_FROM}' AND '${FORMATTED_DATE_TO}'
                          AND a_orig.iata = '${origin}'
                          AND a_dest.iata = '${destination}'
                        ORDER BY fs.date_departure, fs.time_departure
                    "
                    
                    RESULT=$(mysql_query -e "$QUERY")
                    
                    echo ""
                    if [ $(echo "$RESULT" | wc -l) -gt 1 ]; then
                        print_color $YELLOW "Flight Results (Date Range):"
                        echo "$RESULT" | column -t -s $'\t'
                        LAST_QUERY_RESULT="$RESULT"
                    else
                        print_color $YELLOW "No flights found for this route and date range."
                    fi
                    echo ""
                else
                    print_color $RED "Error: Invalid AN command format."
                    print_color $YELLOW "Usage: AN <origin> <destination> <date> [class]"
                    print_color $YELLOW "   or: AN <date> <origin> <destination> <airline>"
                    print_color $YELLOW "   or: AN <origin> <destination> <date_from> <date_to>"
                    continue
                fi
        fi
        
        # Variation 5: AN <origin1> <dest1> <date1> <origin2> <dest2> <date2> - Multi-city search
        elif [ $num_args -eq 7 ]; then
            origin1="${args[1]^^}"
            destination1="${args[2]^^}"
            date_input1="${args[3]}"
            origin2="${args[4]^^}"
            destination2="${args[5]^^}"
            date_input2="${args[6]}"
            
            # Parse first date
            if [[ $date_input1 =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                month_str_1=${date_input1:0:3}
                day_1=${date_input1:3:2}
            elif [[ $date_input1 =~ ^[0-9]{2}[A-Za-z]{3}$ ]]; then
                day_1=${date_input1:0:2}
                month_str_1=${date_input1:2:3}
            else
                print_color $RED "Error: First date must be in MonthDD or DDMON format."
                continue
            fi
            
            if ! FORMATTED_DATE_1=$(date -d "${month_str_1} ${day_1} 2025" +%Y-%m-%d 2>/dev/null); then
                print_color $RED "Error: Invalid first date. Please check the format."
                continue
            fi
            
            # Parse second date
            if [[ $date_input2 =~ ^[A-Za-z]{3}[0-9]{2}$ ]]; then
                month_str_2=${date_input2:0:3}
                day_2=${date_input2:3:2}
            elif [[ $date_input2 =~ ^[0-9]{2}[A-Za-z]{3}$ ]]; then
                day_2=${date_input2:0:2}
                month_str_2=${date_input2:2:3}
            else
                print_color $RED "Error: Second date must be in MonthDD or DDMON format."
                continue
            fi
            
            if ! FORMATTED_DATE_2=$(date -d "${month_str_2} ${day_2} 2025" +%Y-%m-%d 2>/dev/null); then
                print_color $RED "Error: Invalid second date. Please check the format."
                continue
            fi
            
            # Validate that second flight is after or equal to first flight
            if [[ "$FORMATTED_DATE_2" < "$FORMATTED_DATE_1" ]]; then
                print_color $RED "Error: Second flight date must be after first flight date."
                continue
            fi
            
            # Get airport names for segment 1
            origin1_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin1}' LIMIT 1;")
            if [ -z "$origin1_name" ]; then
                print_color $RED "Error: Origin airport '$origin1' not found."
                continue
            fi
            
            destination1_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination1}' LIMIT 1;")
            if [ -z "$destination1_name" ]; then
                print_color $RED "Error: Destination airport '$destination1' not found."
                continue
            fi
            
            # Get airport names for segment 2
            origin2_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${origin2}' LIMIT 1;")
            if [ -z "$origin2_name" ]; then
                print_color $RED "Error: Origin airport '$origin2' not found."
                continue
            fi
            
            destination2_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE iata = '${destination2}' LIMIT 1;")
            if [ -z "$destination2_name" ]; then
                print_color $RED "Error: Destination airport '$destination2' not found."
                continue
            fi
            
            print_color $CYAN "========== Segment 1 =========="
            print_color $BLUE "Origin: $origin1_name ($origin1)"
            print_color $BLUE "Destination: $destination1_name ($destination1)"
            print_color $BLUE "Date: $FORMATTED_DATE_1"
            
            QUERY_1="
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
                WHERE fs.date_departure = '${FORMATTED_DATE_1}'
                  AND a_orig.iata = '${origin1}'
                  AND a_dest.iata = '${destination1}'
            "
            
            RESULT_1=$(mysql_query -e "$QUERY_1")
            
            echo ""
            if [ $(echo "$RESULT_1" | wc -l) -gt 1 ]; then
                print_color $YELLOW "Flight Results (Segment 1):"
                echo "$RESULT_1" | column -t -s $'\t'
            else
                print_color $RED "No flights found for segment 1."
                continue
            fi
            echo ""
            
            print_color $CYAN "========== Segment 2 =========="
            print_color $BLUE "Origin: $origin2_name ($origin2)"
            print_color $BLUE "Destination: $destination2_name ($destination2)"
            print_color $BLUE "Date: $FORMATTED_DATE_2"
            
            QUERY_2="
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
                WHERE fs.date_departure = '${FORMATTED_DATE_2}'
                  AND a_orig.iata = '${origin2}'
                  AND a_dest.iata = '${destination2}'
            "
            
            RESULT_2=$(mysql_query -e "$QUERY_2")
            
            echo ""
            if [ $(echo "$RESULT_2" | wc -l) -gt 1 ]; then
                print_color $YELLOW "Flight Results (Segment 2):"
                echo "$RESULT_2" | column -t -s $'\t'
                # Store only the second result for seat selection
                LAST_QUERY_RESULT="$RESULT_2"
            else
                print_color $RED "No flights found for segment 2."
                continue
            fi
            echo ""
        else
            print_color $RED "Error: Invalid AN command format."
            print_color $YELLOW "Usage: AN <origin> <destination> <date> [class]"
            print_color $YELLOW "   or: AN <date> <origin> <destination> <airline>"
            print_color $YELLOW "   or: AN <origin> <destination> <date_from> <date_to>"
            print_color $YELLOW "   or: AN <origin1> <dest1> <date1> <origin2> <dest2> <date2>"
            continue
        fi
    
    # Add Baggage command
    elif [[ "${flight_command^^}" = "SSR" && "${args[1]^^}" = "BAGO" ]]; then
        if [ ${#args[@]} -lt 5 ]; then
            print_color $RED "Usage: SSR BAGO <ticket_id> <weight> <pieces>"
            continue
        fi
        ssr_ticket_id="${args[2]}"
        ssr_weight="${args[3]}"
        ssr_pieces="${args[4]}"
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
        seat_row=$(mysql_query -N -B -e "SELECT id, flight_schedule_id, aircraft_id FROM seats WHERE ticket_id = '$ssr_ticket_id' LIMIT 1;")
        if [ -z "$seat_row" ]; then
            print_color $RED "Ticket ID not found."
            continue
        fi
        seat_id=$(echo "$seat_row" | awk '{print $1}')
        flight_schedule_id=$(echo "$seat_row" | awk '{print $2}')
        aircraft_id=$(echo "$seat_row" | awk '{print $3}')
        if [ -z "$aircraft_id" ]; then
            # fallback: get aircraft_id from flight_schedules
            aircraft_id=$(mysql_query -N -B -e "SELECT aircraft_id FROM flight_schedules WHERE id = $flight_schedule_id LIMIT 1;")
        fi
        if [ -z "$aircraft_id" ]; then
            print_color $RED "Aircraft not found for this ticket."
            continue
        fi
        # Get aircraft payload_capacity
        payload_capacity=$(mysql_query -N -B -e "SELECT payload_capacity FROM aircraft WHERE id = $aircraft_id LIMIT 1;")
        if [ -z "$payload_capacity" ]; then
            print_color $RED "Aircraft payload capacity not found."
            continue
        fi
        # Calculate total baggage weight for this flight
        total_baggage=$(mysql_query -N -B -e "SELECT IFNULL(SUM(weight),0) FROM baggage WHERE seat_id IN (SELECT id FROM seats WHERE flight_schedule_id = $flight_schedule_id);")
        new_total=$((total_baggage + ssr_weight_val))
        if (( new_total > payload_capacity )); then
            print_color $RED "Cannot add baggage: exceeds aircraft payload capacity ($payload_capacity kg)."
            continue
        fi

        # Insert baggage row
        mysql_query -e "INSERT INTO baggage (pieces, weight, seat_id, passenger_name, ticket_id) VALUES ($ssr_pieces_val, $ssr_weight_val, $seat_id, (SELECT customer_name FROM seats WHERE id = $seat_id), '$ssr_ticket_id');"
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

            available_count=$(mysql_query -N -B -e "SELECT COUNT(*) FROM seats WHERE flight_schedule_id = $flight_no AND class = '$class' AND status = 'available';")

            if (( available_count < num_seats )); then
                print_color $RED "Not enough available seats in class $class. Available: $available_count"
                continue
            fi

            # Get available seats
            available_seats=$(mysql_query -N -B -e "SELECT id FROM seats WHERE flight_schedule_id = $flight_no AND class = '$class' AND status = 'available' ORDER BY id LIMIT $num_seats;")
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

            # Build passenger input from remaining args (skip command and number)
            passenger_input="${args[@]:1}"
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
                mysql_query -e "UPDATE seats SET status='occupied', ticket_id='$ticket_num', customer_name='$name' WHERE id=$sid;"
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
            agency_number="${args[1]}"
            if [[ ! $agency_number =~ ^[0-9]+$ ]]; then
                print_color $RED "Invalid agency number. Must be digits."
                continue
            else
                for sid in $LAST_OCCUPIED_SEATS; do
                    mysql_query -e "UPDATE seats SET agency_number='$agency_number' WHERE id=$sid;"
                done
                print_color $GREEN "Agency number updated."
                WAITING_FOR_AGENCY=false
                WAITING_FOR_CUSTOMER=true
                print_color $GREEN "Please enter customer number using AP command."
            fi
        # Add customer/s number
        elif [ "$WAITING_FOR_CUSTOMER" = true ]; then
            customer_number="${args[1]}"
            if [[ ! $customer_number =~ ^[0-9]+$ ]]; then
                print_color $RED "Invalid customer number. Must be digits."
                continue
            else
                for sid in $LAST_OCCUPIED_SEATS; do
                    mysql_query -e "UPDATE seats SET customer_number='$customer_number' WHERE id=$sid;"
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
        fqd_origin="${args[1]^^}"
        fqd_dest="${args[2]^^}"
        fqd_param3="${args[3]^^}"
        fqd_param4="${args[4]^^}"

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
        origin_id=$(mysql_query -N -B -e "SELECT id FROM airports WHERE iata = '$fqd_origin' LIMIT 1;")
        if [ -z "$origin_id" ]; then
            print_color $RED "Error: Origin airport '$fqd_origin' not found."
            continue
        fi

        # Get destination airport ID
        dest_id=$(mysql_query -N -B -e "SELECT id FROM airports WHERE iata = '$fqd_dest' LIMIT 1;")
        if [ -z "$dest_id" ]; then
            print_color $RED "Error: Destination airport '$fqd_dest' not found."
            continue
        fi

        # Get airport names for display
        origin_airport_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE id = $origin_id;")
        dest_airport_name=$(mysql_query -N -B -e "SELECT airport_name FROM airports WHERE id = $dest_id;")

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

        FQD_RESULT=$(mysql_query -e "$FQD_QUERY")

        echo ""
        if [ $(echo "$FQD_RESULT" | wc -l) -gt 1 ]; then
            print_color $YELLOW "Flight Quotation:"
            echo "$FQD_RESULT" | column -t -s $'\t'
        else
            print_color $RED "No flights found for the specified route and criteria."
        fi
    
    # Void Ticket command
    elif [ "${flight_command^^}" = "TKV" ]; then
        tkv_ticket_id="${args[1]}"
        if [ -z "$tkv_ticket_id" ]; then
            print_color $RED "Error: TKV requires a ticket id."
            continue
        fi
        # Check if ticket exists and is unpaid
        seat_row=$(mysql_query -N -B -e "SELECT id, status, is_paid FROM seats WHERE ticket_id = '$tkv_ticket_id' LIMIT 1;")
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
        mysql_query -e "UPDATE seats SET status='available', customer_name=NULL, customer_number=NULL, agency_number=NULL, ticket_id=NULL, is_paid='unpaid' WHERE id=$seat_id;"
        print_color $GREEN "Ticket $tkv_ticket_id has been voided and seat is now available."
    # Refund Ticket command
    elif [ "${flight_command^^}" = "RFND" ]; then
        rfnd_ticket_id="${args[1]}"
        if [ -z "$rfnd_ticket_id" ]; then
            print_color $RED "Error: RFND requires a ticket id."
            continue
        fi
        # Check if ticket exists and is paid
        seat_row=$(mysql_query -N -B -e "SELECT id, status, is_paid, price, customer_name FROM seats WHERE ticket_id = '$rfnd_ticket_id' LIMIT 1;")
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
        mysql_query -e "UPDATE seats SET status='available', customer_name=NULL, customer_number=NULL, agency_number=NULL, ticket_id=NULL, is_paid='unpaid', price=NULL WHERE id=$seat_id;"
        print_color $GREEN "₱$seat_price has been succesfully refunded to $seat_cust with a ticket of $rfnd_ticket_id"

    # Passenger List command
    elif [ "${flight_command^^}" = "DS" ]; then
        ds_carrier_code="${args[1]}"
        ds_date="${args[2]}"
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
        ds_flight_id=$(mysql_query -N -B -e "SELECT id FROM flight_schedules WHERE carrier_code = '$ds_carrier_code' AND date_departure = '$ds_formatted_date' LIMIT 1;")
        if [ -z "$ds_flight_id" ]; then
            print_color $RED "No flight found for carrier $ds_carrier_code on $ds_formatted_date."
            continue
        fi
        # Fetch passenger names
        ds_passengers=$(mysql_query -N -B -e "SELECT customer_name FROM seats WHERE flight_schedule_id = $ds_flight_id AND customer_name IS NOT NULL;")
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





