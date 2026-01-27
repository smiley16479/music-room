#!/bin/bash

# User Generator Script (Bash version)
# This script generates fake users by calling the backend API

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000/api}"
COUNT="${1:-10}"
PASSWORD="${PASSWORD:-Password123!}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Arrays for fake data
FIRST_NAMES=(
  "Alice" "Bob" "Charlie" "Diana" "Emma" "Frank" "Grace" "Henry"
  "Ivy" "Jack" "Kate" "Liam" "Mia" "Noah" "Olivia" "Peter"
  "Quinn" "Rachel" "Sam" "Tara" "Uma" "Victor" "Wendy" "Xander"
  "Yara" "Zoe" "Alex" "Blake" "Casey" "Drew"
)

LAST_NAMES=(
  "Smith" "Johnson" "Williams" "Brown" "Jones" "Garcia" "Miller" "Davis"
  "Rodriguez" "Martinez" "Hernandez" "Lopez" "Wilson" "Anderson" "Thomas" "Taylor"
  "Moore" "Jackson" "Martin" "Lee" "Walker" "Hall" "Allen" "Young"
)

CITIES=(
  "New York" "Los Angeles" "Chicago" "Houston" "Phoenix" "Philadelphia"
  "Seattle" "Denver" "Boston" "Portland" "Nashville" "Miami" "Atlanta"
  "Paris" "London" "Tokyo" "Berlin" "Madrid" "Rome" "Amsterdam"
)

GENRES=(
  "Rock" "Pop" "Jazz" "Classical" "Hip Hop" "Rap"
  "Blues" "Country" "Electronic" "Reggae" "Metal" "R&B"
)

BIOS=(
  "Music lover and aspiring musician 🎵"
  "Just here to vibe and share good tunes 🎶"
  "Life is better with music 🎧"
  "Always looking for new music recommendations!"
  "Playlist curator extraordinaire ✨"
  "Music is my therapy 🎸"
)

VISIBILITIES=("public" "friends" "private")

# Functions
random_element() {
  local array=("$@")
  local count=${#array[@]}
  local index=$((RANDOM % count))
  echo "${array[$index]}"
}

random_date() {
  # Generate a random birth date (18-70 years old)
  local year=$(($(date +%Y) - 18 - (RANDOM % 52)))
  local month=$((1 + RANDOM % 12))
  local day=$((1 + RANDOM % 28))
  printf "%04d-%02d-%02d" $year $month $day
}

random_genres() {
  local count=$((2 + RANDOM % 4))
  local selected=()
  for ((i=0; i<count; i++)); do
    selected+=("$(random_element "${GENRES[@]}")")
  done
  # Join array with commas
  local IFS=','
  echo "${selected[*]}"
}

create_user() {
  local index=$1
  local first_name=$(random_element "${FIRST_NAMES[@]}")
  local last_name=$(random_element "${LAST_NAMES[@]}")
  local email="${first_name,,}.${last_name,,}${index}@test.com"
  local display_name="${first_name} ${last_name}"
  
  local bio=""
  if [ $((RANDOM % 10)) -gt 3 ]; then
    bio=$(random_element "${BIOS[@]}")
  fi
  
  local location=""
  if [ $((RANDOM % 10)) -gt 4 ]; then
    location=$(random_element "${CITIES[@]}")
  fi
  
  local birth_date=$(random_date)
  local genres=$(random_genres)
  
  # Create JSON payload
  local json_payload=$(cat <<EOF
{
  "email": "$email",
  "password": "$PASSWORD",
  "displayName": "$display_name",
  "bio": "$bio",
  "location": "$location",
  "birthDate": "$birth_date",
  "displayNameVisibility": "$(random_element "${VISIBILITIES[@]}")",
  "bioVisibility": "$(random_element "${VISIBILITIES[@]}")",
  "birthDateVisibility": "$(random_element "${VISIBILITIES[@]}")",
  "locationVisibility": "$(random_element "${VISIBILITIES[@]}")",
  "musicPreferences": ["$(echo $genres | sed 's/,/","/g')"],
  "musicPreferenceVisibility": "$(random_element "${VISIBILITIES[@]}")"
}
EOF
)

  # Make API request
  local response=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Content-Type: application/json" \
    -d "$json_payload" \
    "$BASE_URL/auth/register")
  
  local http_code=$(echo "$response" | tail -n1)
  local body=$(echo "$response" | head -n-1)
  
  if [ "$http_code" -eq 201 ] || [ "$http_code" -eq 200 ]; then
    echo -e "${GREEN}✅${NC} Created: $email"
    return 0
  else
    local error_msg=$(echo "$body" | grep -o '"message":"[^"]*"' | cut -d'"' -f4)
    echo -e "${RED}❌${NC} Failed: $email - $error_msg"
    return 1
  fi
}

# Main script
echo -e "${BLUE}🚀 User Generator Script${NC}"
echo "========================"
echo "Base URL: $BASE_URL"
echo "Users to generate: $COUNT"
echo "Password: $PASSWORD"
echo ""

success_count=0
failed_count=0

for ((i=1; i<=COUNT; i++)); do
  echo -n "[$i/$COUNT] "
  if create_user $i; then
    ((success_count++))
  else
    ((failed_count++))
  fi
  sleep 0.1  # Small delay to avoid overwhelming the server
done

echo ""
echo "========================"
echo -e "${BLUE}📊 Summary${NC}"
echo "========================"
echo -e "${GREEN}✅ Successfully created: $success_count${NC}"
echo -e "${RED}❌ Failed: $failed_count${NC}"
echo ""
echo "💡 Tips:"
echo "  - All users have the same password: $PASSWORD"
echo "  - Email format: firstname.lastname<number>@test.com"
echo "  - Users need to verify their email before logging in"
echo "  - Check the backend logs for verification links"

exit $failed_count
