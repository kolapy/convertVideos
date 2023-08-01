#!/bin/bash

#This script will convert mov files to h265 mp4s.
#Run this script in the directory containing your footage.
start_time=$(date +%s.%N)

# Check for dependencies
check_dependencies() {
  if ! command -v ffmpeg &>/dev/null; then
    echo -e "${ERROR}Error: 'ffmpeg' is not installed. Please install it before running this script."
    exit 1
  fi
}

#add a signnature to sign the meta data of each file we process
signature="Compressed with convertVideos by Greg J."

# ANSI color and formatting escape sequences
BOLD='\033[1m'
COLOR='\033[0;33m'  # Yellow
COLOR2='\033[0;36m'  # Cyan
NC='\033[0m'       # No Color
ERROR='\033[0;31m' #Red

# Set the default encoder and quality value
DEFAULT_ENCODER='libx265'
DEFAULT_QUALITY='28'

# Function to display the help information
display_help() {
  echo
  echo -e "${COLOR2}Usage: $0 [encoder] [quality]"
  echo -e "${COLOR2}encoder: Specify the video encoder. Valid options: ${NC}h264, h265"
  echo -e "${COLOR2}quality: Specify the output quality. Valid options: ${NC}low, medium, high"
  echo -e "${COLOR2}If no encoder or quality options are provided, default values will be used.${NC}"
}

# Function to log the summary of the conversion process
log_summary() {
  local total_files=$(find . -type f -name "*.mov" | wc -l)
  local converted_files=$(grep -c "Converted:" "$log_file")
  local error_files=$(grep -c "Error" "$log_file")
  
  echo >> "$log_file" # Add a blank line before the summary
  echo "---- Summary ----" >> "$log_file"
  echo "Total files processed: $total_files" >> "$log_file"
  echo "Files successfully converted: $converted_files" >> "$log_file"
  echo "Files with errors: $error_files" >> "$log_file"
}

# Function to check and set the encoder and quality settings based on user input
set_encoder_and_quality() {
  local encoder="$DEFAULT_ENCODER"
  local quality="$DEFAULT_QUALITY"

  if [ "$1" = "h264" ]; then
    encoder='libx264'
  elif [ "$1" = "h265" ]; then
    encoder='libx265'
  fi

  if [ "$2" = "low" ]; then
    quality="51"
  elif [ "$2" = "medium" ]; then
    quality="28"
  elif [ "$2" = "high" ]; then
    quality="20"
  fi

  ENCODER="$encoder"
  QUALITY="$quality"
}

#Set up the file creation mode.   Either placed in an output folder or next to the original files.
production_mode(){
  local file="$1"
  local mode="$2"
  local output

  if [ "$mode" = "-p" ] || [ "$mode" = "--production" ]; then
    output="${file%.*}-Compressed.mp4"
  else
    output_folder="output_COMPRESSED"
    mkdir -p "${output_folder}"

    # Get the relative path of the file's directory to preserve folder structure in the output
    relative_path=$(dirname "${file}")
    # Create the corresponding directory structure in the output folder
    mkdir -p "${output_folder}/${relative_path}"
    # Construct the output file path
    output="${output_folder}/${relative_path}/$(basename "${file%.*}").mp4"
  fi

  echo "$output"
}


#Argument processing
if [ "$#" -eq 0 ]; then
  # If no arguments provided, use default encoder and quality
  ENCODER="$DEFAULT_ENCODER"
  QUALITY="$DEFAULT_QUALITY"
elif [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  # Display help information if the user asks for help
  display_help
  exit 0
elif [ "$#" -eq 1 ] && { [ "$1" = "h264" ] || [ "$1" = "h265" ]; }; then
  # Set encoder based on user input, use default quality
  set_encoder_and_quality "$1" "$DEFAULT_QUALITY"
elif [ "$#" -eq 2 ] && { [ "$1" = "h264" ] || [ "$1" = "h265" ]; } && { [ "$2" = "low" ] || [ "$2" = "medium" ] || [ "$2" = "high" ]; }; then
  # Set encoder and quality based on user input
  set_encoder_and_quality "$1" "$2"
elif [ "$#" -eq 3 ] && { [ "$1" = "h264" ] || [ "$1" = "h265" ]; } && { [ "$2" = "low" ] || [ "$2" = "medium" ] || [ "$2" = "high" ]; } && { [ "$3" = "-p" ] || [ "$3" = "--production " ]; }; then
  # Set encoder and quality based on user input AND use production mode
  set_encoder_and_quality "$1" "$2"
else
  echo -e "${ERROR}Invalid argument. Use --help or -h for usage information."
  exit 1
fi


# Log file path
log_file="conversion_log.txt"
echo "The following files have been converted" >> "$log_file"
echo >> "$log_file"

MODE="$3"
#The encoding loop using find to locate .mov files recursively
find . -type f -name "*.mov" -print0 | while IFS= read -r -d '' file; do
  if [ -f "$file" ]; then

    output=$(production_mode "$file" "$MODE")
    
    echo -e "${BOLD}${COLOR}Converting $file to $output${NC}"
    #print the value of quality
    echo -e "${BOLD}${COLOR}CRF =${QUALITY}${NC}"
    ffmpeg -hide_banner -loglevel info -stats -i "$file" -movflags use_metadata_tags -metadata sign="$signature" -c:v ${ENCODER} -crf ${QUALITY} "$output" -preset ultrafast < /dev/null #CRF value can be changed if you need to tweak the quality.  0-51
    
    # Log the conversion status (success or error) to the log file
    if [ $? -eq 0 ]; then
      echo "Converted: $output" >> "$log_file"
    else
      echo "Error: $file" >> "$log_file"
    fi
  fi
done

end_time=$(date +%s.%N)
elapsed_time=$(awk -v end=$end_time -v start=$start_time 'BEGIN {print end - start}')
elapsed_minutes=$(awk -v t="$elapsed_time" 'BEGIN {print int(t / 60 * 100) / 100}')

# Log the summary of the conversion process
log_summary

#Log footer
echo >>"$log_file"
echo -e "Converion completed in $elapsed_minutes minutes\n">> "$log_file"
echo "$signature">> "$log_file"

#Terminal output
echo -e "${BOLD}${COLOR}Total script execution time: $elapsed_minutes minutes"
