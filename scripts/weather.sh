#!/bin/bash
set -euo pipefail;

# Weather fetching script for Nonchalant
# Usage: weather.sh [location]
# If no location is provided, uses GeoIP to determine location
# Output: JSON with weather data or error

LOCATION="${1:-}"
MAX_RETRIES=3
RETRY_DELAY=2

# Function to make HTTP request with retries
http_get() {
	local url="$1"
	local max_attempts="${2:-$MAX_RETRIES}"
	local attempt=1
	local response=""

	while [[ $attempt -le $max_attempts ]]; do
		# -f rejects HTTP errors such as the 429 response that ipapi.co
		# previously passed to jq as if it were valid JSON.
		response=$(curl -fsS --max-time 15 --retry 1 --retry-delay 1 "$url" 2>/dev/null) || response=""
		if [[ -n "$response" && "$response" != "null" ]]; then
			echo "$response"
			return 0
		fi
		attempt=$((attempt + 1))
		sleep $RETRY_DELAY
	done

	return 1
}

# Build the location metadata emitted alongside the Open-Meteo response.
location_json() {
	local lat="$1" lon="$2" name="$3" region="$4" country="$5"
	jq -cn \
		--arg lat "$lat" \
		--arg lon "$lon" \
		--arg name "$name" \
		--arg region "$region" \
		--arg country "$country" \
		'{
			latitude: ($lat | tonumber),
			longitude: ($lon | tonumber),
			name: (if $name == "" then $lat + ", " + $lon else $name end),
			region: $region,
			country: $country
		}'
}

# Resolve GeoIP coordinates and retain the city metadata from the same lookup.
get_geoip_location() {
	local response lat lon loc name region country

	# GeoIP services occasionally rate-limit public traffic, so validate each
	# response and fall through instead of making weather depend on one host.
	response=$(http_get "https://ipwho.is/" 1) || response=""
	if [[ -n "$response" ]]; then
		lat=$(jq -r 'if .success == true then .latitude // empty else empty end' <<<"$response" 2>/dev/null) || lat=""
		lon=$(jq -r 'if .success == true then .longitude // empty else empty end' <<<"$response" 2>/dev/null) || lon=""
		if [[ -n "$lat" && -n "$lon" ]]; then
			name=$(jq -r 'if .success == true then .city // empty else empty end' <<<"$response" 2>/dev/null) || name=""
			region=$(jq -r 'if .success == true then .region // empty else empty end' <<<"$response" 2>/dev/null) || region=""
			country=$(jq -r 'if .success == true then .country // empty else empty end' <<<"$response" 2>/dev/null) || country=""
			location_json "$lat" "$lon" "$name" "$region" "$country"
			return 0
		fi
	fi

	response=$(http_get "https://ipinfo.io/json" 1) || response=""
	if [[ -n "$response" ]]; then
		loc=$(jq -r '.loc // empty' <<<"$response" 2>/dev/null) || loc=""
		if [[ "$loc" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
			lat="${loc%,*}"
			lon="${loc#*,}"
			name=$(jq -r '.city // empty' <<<"$response" 2>/dev/null) || name=""
			region=$(jq -r '.region // empty' <<<"$response" 2>/dev/null) || region=""
			country=$(jq -r '.country // empty' <<<"$response" 2>/dev/null) || country=""
			location_json "$lat" "$lon" "$name" "$region" "$country"
			return 0
		fi
	fi

	response=$(http_get "https://api.ipapi.is/" 1) || response=""
	if [[ -n "$response" ]]; then
		lat=$(jq -r '.location.latitude // empty' <<<"$response" 2>/dev/null) || lat=""
		lon=$(jq -r '.location.longitude // empty' <<<"$response" 2>/dev/null) || lon=""
		if [[ -n "$lat" && -n "$lon" ]]; then
			name=$(jq -r '.location.city // .city // empty' <<<"$response" 2>/dev/null) || name=""
			region=$(jq -r '.location.state // .location.region // .region // empty' <<<"$response" 2>/dev/null) || region=""
			country=$(jq -r '.location.country // .country // empty' <<<"$response" 2>/dev/null) || country=""
			location_json "$lat" "$lon" "$name" "$region" "$country"
			return 0
		fi
	fi

	echo '{"error": "Could not determine location from GeoIP providers"}'
	return 1
}

# Function to geocode a city name
geocode_city() {
	local city="$1"
	local encoded_city
	encoded_city=$(echo -n "$city" | jq -sRr @uri)

	local response
	response=$(http_get "https://geocoding-api.open-meteo.com/v1/search?name=${encoded_city}") || response=""

	if [[ -z "$response" ]]; then
		echo '{"error": "Geocoding request failed"}'
		return 1
	fi

	local lat lon name region country
	lat=$(jq -r '.results[0].latitude // empty' <<<"$response") || lat=""
	lon=$(jq -r '.results[0].longitude // empty' <<<"$response") || lon=""

	if [[ -z "$lat" || -z "$lon" ]]; then
		echo '{"error": "City not found"}'
		return 1
	fi

	name=$(jq -r '.results[0].name // empty' <<<"$response") || name=""
	region=$(jq -r '.results[0].admin1 // empty' <<<"$response") || region=""
	country=$(jq -r '.results[0].country // empty' <<<"$response") || country=""
	location_json "$lat" "$lon" "$name" "$region" "$country"
}

# Function to fetch weather data
fetch_weather() {
	local lat="$1"
	local lon="$2"
	local location="$3"

	local url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,apparent_temperature,is_day,weather_code,wind_speed_10m&hourly=temperature_2m,weather_code,precipitation_probability&daily=temperature_2m_max,temperature_2m_min,sunrise,sunset,weathercode&timezone=auto&forecast_days=7"

	local response
	response=$(http_get "$url") || response=""

	if [[ -z "$response" ]]; then
		echo '{"error": "Weather API request failed"}'
		return 1
	fi

	# Validate modern current fields before adapting them to the legacy consumer shape.
	if ! jq -e '
		.current != null
		and (.current.temperature_2m | type == "number")
		and (.current.weather_code | type == "number")
		and (.current.wind_speed_10m | type == "number")
		and (.current.apparent_temperature | type == "number")
		and (.current.is_day | type == "number")
		and (.current.is_day == 0 or .current.is_day == 1)
		and .daily != null
		and (.hourly.time | type == "array")
		and (.hourly.temperature_2m | type == "array")
		and (.hourly.weather_code | type == "array")
		and (.hourly.precipitation_probability | type == "array")
	' >/dev/null <<<"$response"; then
		echo '{"error": "Invalid weather API response"}'
		return 1
	fi

	jq -c --argjson location "$location" '
		. + {
			location: $location,
			current_weather: {
				temperature: .current.temperature_2m,
				weathercode: .current.weather_code,
				windspeed: .current.wind_speed_10m
			}
		}
	' <<<"$response"
}

# Main logic
main() {
	local location lat lon

	if [[ -z "$LOCATION" ]]; then
		# No location provided, use GeoIP and its city metadata.
		if ! location=$(get_geoip_location); then
			echo "$location"
			return 1
		fi
	elif [[ "$LOCATION" =~ ^-?[0-9]+\.?[0-9]*,-?[0-9]+\.?[0-9]*$ ]]; then
		# Coordinates are honest place labels unless reverse-geocoded.
		lat="${LOCATION%,*}"
		lon="${LOCATION#*,}"
		location=$(location_json "$lat" "$lon" "${lat}, ${lon}" "" "")
	else
		# Preserve the matching city's metadata from Open-Meteo geocoding.
		if ! location=$(geocode_city "$LOCATION"); then
			echo "$location"
			return 1
		fi
	fi

	lat=$(jq -r '.latitude' <<<"$location")
	lon=$(jq -r '.longitude' <<<"$location")

	fetch_weather "$lat" "$lon" "$location"
}

main
