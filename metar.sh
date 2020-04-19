#!/bin/bash
# Metar based weather visualiser and logger
# TODO add config file containing units settings?

DEBUG=true # <true>/<false>

METAR_RLPCZ_LKPR_URL="https://meteo.rlp.cz/LKPR_meteo.htm"
METAR_RLPCZ_LKTB_URL="https://meteo.rlp.cz/LKTB_meteo.htm"

# Debug output
debug () {
    [[ $DEBUG == "true" ]] && echo [ DEBUG ] $@
}

# Get METAR message from web
get_metar_rlpcz () {
    local ICAO_CODE=$1
    case $ICAO_CODE in
        'LKPR' | 'Prague' | 'Praha')
            curl -s $METAR_RLPCZ_LKPR_URL > .web_data
            ;;
        'LKTB' | 'Brno')
            curl -s $METAR_RLPCZ_LKTB_URL > .web_data
            ;;
        *)
            echo "Invalid od unsupported ICAO airport code." 
            ;;
    esac
    echo $(cat .web_data | grep "METAR.*=" | tr -d "\t")
    rm .web_data
}

# Parse METAR message to the individual values
# Example messages:
# METAR LKTB 181500Z 20007KT 170V230 CAVOK 21/05 Q1013 NOSIG RMK REG QNH 1012=
# METAR LKTB 190900Z VRB01KT CAVOK 10/06 Q1016 NOSIG RMK REG QNH 1014=
# Return format: "<date>,<time>,<temperature>,<dew point>,<relative humidity>,<pressure>,<wind speed>,<wind direction>"
parse_metar () {
    metar_msg=$1
   
    # Parse date 
    local date=$(for i in $metar_msg; do echo $i; done | grep -E ^[0-9]{6}Z$ | cut -c1-2)

    # Parse time
    local time=$(for i in $metar_msg; do echo $i; done | grep -E ^[0-9]{6}Z$ | cut -c3-6)

    # Parse temperature
    local temp=$(for i in $metar_msg; do echo $i; done | grep -E ^M?[0-9]{2}/M?[0-9]{2}$ | cut -f1 -d/)
    if [[ $(echo $temp | grep ^M) ]];
    then
        temp=$(tr M - <<< $(echo $temp));
    fi
    
    # Parse dew point
    local dew=$(for i in $metar_msg; do echo $i; done | grep -E ^M?[0-9]{2}/M?[0-9]{2}$ | cut -f2 -d/)
    if [[ $(echo $dew | grep ^M) ]];
    then
        dew=$(tr M - <<< $(echo $dew));
    fi
    # TODO compute relative humidity

    # Parse atmospheric pressure
    local pres=$(for i in $metar_msg; do echo $i; done | grep -E ^Q[0-9]{4}$ | tr -d Q)

    # Parse wind speed
    local wspd=$(for i in $metar_msg; do echo $i; done | grep -E "^[0-9]{5}KT$|VRB[0-9]{2}KT" | cut -c4-5)
    # TODO varying wind direction, eg 20007KT 170V230
    # TODO parse speed unit, convert to m/s
    
    # Parse wind direction
    local wdir=$(for i in $metar_msg; do echo $i; done | grep -E "^[0-9]{5}KT$|VRB[0-9]{2}KT" | cut -c1-3)

    echo $date,$time,$temp,$dew,,$pres,$wspd,$wdir
}

# Program structure
case $1 in
    parse)
        # TODO check argument validity
        parse_metar "$2"
        ;;
    get)
        # TODO check argument validity
        get_metar_rlpcz "$2"
        ;;
    weather)
        metar_msg=$(get_metar_rlpcz $2)
        #metar_msg="METAR LKTB 190900Z VRB01KT CAVOK 10/06 Q1016 NOSIG RMK REG QNH 1014=" # debug
        debug $metar_msg
        metar_data=$(parse_metar "$metar_msg")
        debug $metar_data
        # TODO add detection whereas the value is available (not-empty string)
        echo Date: day $(echo $metar_data | cut -f1 -d,) 
        echo Time: $(echo $metar_data | cut -f2 -d,) UTC
        echo Temperature: $(echo $metar_data | cut -f3 -d, | awk '{printf "%d\n",$0}')\'C
        echo Dew point: $(echo $metar_data | cut -f4 -d, | awk '{printf "%d\n",$0}')\'C
        echo Rel. humidity: --
        echo Pressure: $(echo $metar_data | cut -f6 -d, | awk '{printf "%d\n",$0}') hPa
        echo Wind speed: $(echo $metar_data | cut -f7 -d, | awk '{printf "%d\n",$0}')  kt
        wdir=$(echo $metar_data | cut -f8 -d, | awk '{printf "%d\n",$0}')
        if [[ $wdir == "VRB" ]]; then
            wdir="variable"
            echo Wind direction: $wdir
        else
            echo Wind direction: $wdir\'
        fi
        ;;
    "")
        echo "Argument missing."
        echo "Use <parse>, <get>, or <weather>."
        exit 1
        ;;
    *)
        echo "Invalid argument."
        echo "Use <parse>, <get>, or <weather>."
        exit 1
        ;;
esac
