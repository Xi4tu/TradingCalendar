#!/bin/bash

# Colours
greenColour="\e[0;32m\033[1m"
endColour="\033[0m\e[0m"
redColour="\e[0;31m\033[1m"
blueColour="\e[0;34m\033[1m"
yellowColour="\e[0;33m\033[1m"
purpleColour="\e[0;35m\033[1m"
turquoiseColour="\e[0;36m\033[1m"
grayColour="\e[0;37m\033[1m"


# Handler signal
function ctrl_c() {
  echo -e "\n\n${redColour}[!] SALIENDO ...${endColour}"
  tput cnorm && exit 1
}

# Capture signal
trap ctrl_c INT

function helpPanel() {
  echo -e "${yellowColour}[+] USO: ${endColour}"
  echo -e "${purpleColour}\tw) Obtener noticias para esta semana ${endColour}"
  echo -e "${purpleColour}\tn) Obtener noticias semana siguiente ${endColour}"
  echo -e "${purpleColour}\tc) Filtrar noticias por currency (AUD,CAD,CHF,CNY,EUR,GBP,JPY,NZD,USD) ${endColour}"
  echo -e "${purpleColour}\ti) Filtrar noticias por impacto (Low,Medium,High) ${endColour}"
  echo -e "${purpleColour}\tb) Obtener días de Bank Holiday para este mes ${endColour}"
  echo -e "${yellowColour}\n[+] EJEMPLOS: ${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -w${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -w -c USD -i High${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -n -c USD -i High${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -w -c USD${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -n -i High${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -b${endColour}"
  echo -e "${grayColour}\t./TradingCalendar.sh -b -c EUR${endColour}"
 
  exit 1
}

function getWeekNews() {

  # Request data
  if [ $1 -eq 1 ]; then
    curl -X GET "https://www.forexfactory.com/calendar?week=next" \
    -H "Host: www.forexfactory.com" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0" --output WeekNews.txt &>/dev/null
  else
    curl -X GET "https://www.forexfactory.com/calendar?week=this" \
    -H "Host: www.forexfactory.com" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0" --output WeekNews.txt &>/dev/null
  fi

  if [ -r "WeekNews.txt" ]; then
    tput civis
    data="$(cat WeekNews.txt | grep -oP "^days: \K.*[]}]")"
    for i in $(seq 1 5); do
      date="$(echo $data | jq ".[$i].date" | sed 's/<span>//g' | sed 's/<\/span>//g' | tr -d '"')"
      echo -e "\n\n${turquoiseColour}$(date --date="$date" +"%A - %d/%m/%Y" | sed 's/\b\(.\)/\u\1/')${endColour}"
      echo -e "${grayColour}--------------------------------${endColour}"

      for j in $(seq 1 30); do
        name="$(echo "$data" | jq ".[$i].events | .[$j] | .name" | tr -d '"')"
        currency="$(echo $data | jq ".[$i].events | .[$j] | .currency" | tr -d '"')"
        impact="$(echo $data | jq ".[$i].events | .[$j] | .impactTitle" | tr -d '"' | cut -d " " -f 1)"
        time="$(echo $data | jq ".[$i].events | .[$j] | .timeLabel" | tr -d '"')"

        if [ $# -eq 3 ]; then # ./TradingCalendar.sh -w -c <currency> -i <impact> | # ./TradingCalendar.sh -n -c <currency> -i <impact>
          currency_par="$2"
          impact_par="$3"
          if [ "$currency" != "$currency_par" -o "$impact" != "$impact_par" ]; then
            continue
          fi
        else 
          if [ $# -eq 2 ]; then
            # Filter by currency
            if [ $chivato_currency -eq 1 ]; then
              currency_par="$2"
              if [ "$currency" != "$currency_par" ]; then
                continue
              fi
            else # Filter by impact
              if [ $chivato_impact -eq 1 ]; then
                impact_par="$2"
                if [ "$impact" != "$impact_par" ]; then
                  continue
                fi
              fi
            fi
          fi

        fi
        

        # Show results
        if [ "$name" != "null" ]; then
          if echo $impact | grep "High" >/dev/null; then
            echo -e "${purpleColour}$currency${endColour} | ${redColour}$name${endColour} | ${blueColour}$time ${endColour}"
          elif echo $impact | grep "Medium" >/dev/null; then
            echo -e "${purpleColour}$currency${endColour} | ${yellowColour}$name${endColour} | ${blueColour}$time ${endColour}"
          elif echo $impact | grep "Low" > /dev/null; then
            echo -e "${purpleColour}$currency${endColour} | ${greenColour}$name${endColour} | ${blueColour}$time ${endColour}"
          else 
            echo -e "${purpleColour}$currency${endColour} | ${grayColour}$name${endColour} | ${blueColour}$time ${endColour}"
          fi    
        else
          break
        fi
      done
    done

    echo -e "${grayColour}--------------------------------${endColour}"
    rm WeekNews.txt >/dev/null
    tput cnorm && exit 0

  else
    echo -e "\n ${redColour}[!] Error de lectura${endColour}"
    exit 1
  fi
}

getBankHolidaysDays() {
  curl -X GET "https://www.forexfactory.com/calendar?month=this" \
    -H "Host: www.forexfactory.com" \
    -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; rv:102.0) Gecko/20100101 Firefox/102.0" --output MonthData.txt &>/dev/null

  if [ -r "MonthData.txt" ]; then
    tput civis
    if [ $chivato_currency -eq 1 ]; then  
      data="$(cat "MonthData.txt" | grep -oP "days:\K.*" | sed 's/.$//' | jq '.[].events | .[] | select(.name|test(".*Bank Holiday.*")) | select(.currency=="'$1'") | .date + ":" + .currency + ":" + .name' | tr -d '"')"
    else
      data="$(cat "MonthData.txt" | grep -oP "days:\K.*" | sed 's/.$//' | jq '.[].events | .[] | select(.name|test(".*Bank Holiday.*")) | .date + ":" + .currency + ":" + .name' | tr -d '"')"
    fi
    if [ "$data" ]; then
      echo "$data" | while read linea; do
        date="$(echo $linea | cut -d ":" -f 1)"
        date="$(date --date="$date" +"%d/%m/%y")"
        currency="$(echo $linea | cut -d ":" -f 2)"
        name="$(echo $linea | cut -d ":" -f 3)"
        today="$(date | cut -d " " -f 2)"
        if [ $today -gt $(echo $date | cut -d "/" -f 1) ]; then
          echo -e "\n${redColour}[-] ${endColour}${grayColour}$date - $currency - $name${endColour}"
        else
          echo -e "\n${yellowColour}[+] ${endColour}${turquoiseColour}$date - $currency - $name${endColour}"
        fi
      done
    else
      echo -e "\n ${redColour}[!] NO SE HAN ENCONTRADO RESULTADOS${endColour}"
      rm MonthData.txt >/dev/null
      tput cnorm && exit 1
    fi
    rm MonthData.txt >/dev/null
    tput cnorm && exit 0
  else
    echo -e "\n ${redColour}[!] Error de lectura${endColour}"
    exit 1
  fi

}

function currencyValidation() {
  declare -a values
  values=('AUD' 'CAD' 'CHF' 'CNY' 'EUR' 'GBP' 'JPY' 'NZD' 'USD')

  for i in "${values[@]}"; do
    if [ "$i" == "$1" ]; then
      return
    fi
  done
  echo -e "\n ${redColour}[!] Valor de currency no válido.\n ${grayColour}Valores válidos: ${values[@]}${endColour}"
  exit 1
}

function impactValidation() {
  declare -a values
  values=('High' 'Medium' 'Low')

  for i in "${values[@]}"; do
    if [ "$i" == "$1" ]; then
      return
    fi
  done
  echo -e "\n ${redColour}[!] Valor de impact no válido.\n ${grayColour}Valores válidos: ${values[@]}${endColour}"
  exit 1

}

# Indicadores
declare -i parameter_counter=0

# Chivato
declare -i chivato_currency=0
declare -i chivato_impact=0

while getopts "wnbhc:i:" arg; do
  case $arg in
    w) let parameter_counter+=3;;
    n) let parameter_counter+=4;;
    b) let parameter_counter+=6;;
    h) let parameter_counter+=7;;
    c) currency="$OPTARG"; let chivato_currency+=1;;
    i) impact="$OPTARG"; let chivato_impact+=1;;
  esac
done

if [ $parameter_counter -eq 3 -a $chivato_currency -eq 1 -a $chivato_impact -eq 1 ]; then
    impactValidation $impact
    currencyValidation $currency
    getWeekNews 0 $currency $impact
elif [ $parameter_counter -eq 4 -a $chivato_currency -eq 1 -a $chivato_impact -eq 1 ]; then
    impactValidation $impact
    currencyValidation $currency
    getWeekNews 1 $currency $impact
elif [ $parameter_counter -eq 3 -a $chivato_currency -eq 1 ]; then
  currencyValidation $currency
  getWeekNews 0 $currency
elif [ $parameter_counter -eq 4 -a $chivato_currency -eq 1 ]; then
  currencyValidation $currency
  getWeekNews 1 $currency
elif [ $parameter_counter -eq 3 -a $chivato_impact -eq 1 ]; then
  impactValidation $impact
  getWeekNews 0 $impact 
elif [ $parameter_counter -eq 4 -a $chivato_impact -eq 1 ]; then
  impactValidation $impact
  getWeekNews 1 $impact
elif [ $parameter_counter -eq 6 -a $chivato_currency -eq 1 ]; then
  currencyValidation $currency
  getBankHolidaysDays $currency
elif [ $parameter_counter -eq 3 -a $# -eq 1 ]; then
  getWeekNews 0
elif [ $parameter_counter -eq 4 -a $# -eq 1 ]; then
  getWeekNews 1
elif [ $parameter_counter -eq 6 -a $# -eq 1 ]; then
  getBankHolidaysDays
elif [ $parameter_counter -eq 7 -a $# -eq 1 ]; then
  helpPanel
else
  helpPanel
fi

