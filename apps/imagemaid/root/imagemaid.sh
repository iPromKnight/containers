#!/bin/bash

if [[ -z "$IMAGEMAID_ENABLED" ]]; 
then
    echo "IMAGEMAID_ENABLED env var not set, doing nothing.."
    sleep infinity
elif [[ -z "$PLEX_TOKEN" ]]; 
then
    echo "PLEX_TOKEN not set, can't continue :("
    sleep infinity 
fi

echo "Press any key to drop to a shell, or wait 10 seconds for a normal start..."

# -t 5: Timeout of 5 seconds
read -s -n 1 -t 10

if [ $? -eq 0 ]; then
    echo "You pressed a key! Dropping to shell.."

    items=(1 "Run everything now!"
        2 "Empty trash now"
        3 "Clean bundles now"
        4 "Optimize DB now"
        5 "Photo Transcoder now"
        6 "Run on schedule"
        )

    while choice=$(dialog --title "$TITLE" \
                    --menu "Pick your task:" 20 40 6 "${items[@]}" \
                    2>&1 >/dev/tty)
        do
        case $choice in
            1) python3 /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
            2) EMPTY_TRASH=true python3 -u /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
            3) CLEAN_BUNDLES=true python3 -u /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
            4) OPTIMIZE_DB=true python3 -u /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
            5) PHOTO_TRANSCODER=true python3 -u /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
            *) SCHEDULE=${SCHEDULE:-'08:00|weekly(sunday)'} python3 -u /imagemaid.py
               read -n 1 -s -r -p "Press any key to continue"
               ;; 
        esac
    done
    clear 
else
    echo "Timeout reached, running ImageMaid on schedule (${SCHEDULE:-'08:00|weekly(sunday)'})... (hit CTRL-C and then ENTER to restart)"
    SCHEDULE=${SCHEDULE:-'08:00|weekly(sunday)'} python3 -u /imagemaid.py
fi
