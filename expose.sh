#!/usr/bin/env bash
SECONDS=0

topdir=$(pwd)
scriptdir=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )

draft=false
project=$(ls "$topdir/projects" | head -1)
proj_dir="$topdir/projects/$project"
while getopts ":dp:" opt; do
  case "${opt}" in
    d)
		echo "Draft mode On"
		draft=true
		;;
	p)
		if [ -d "$topdir/projects/${OPTARG}" ]
		then
			echo "using project: ${OPTARG}"
			project=${OPTARG}
			proj_dir="$topdir/projects/${OPTARG}"
		else
			echo "project '${OPTARG}' not found"
			exit
		fi
		;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

# configuration

# Source project configuration file if it exists in the project directory
if [ -f "$proj_dir/config.sh" ]; then
	. "$proj_dir/config.sh"
fi

site_title=${site_title:-"My Awesome Photos"}
site_copyright=${site_copyright:-"© $(date +%Y)"}
nav_title=${nav_title:-"Pages"}

theme=${theme:-"default"}
theme_dir=${theme_dir:-"$topdir/themes/$theme"}
in_dir=${in_dir:-"$proj_dir/input"}
out_dir=${out_dir:-"$topdir/output/$project"}

# Source theme configuration file if it exists in the theme directory
if [ -f "$theme_dir/config.sh" ]; then
  	. "$theme_dir/config.sh"
fi

# widths to scale images to (heights are calculated from source images)
resolution=${resolution:-(2560 1920 1280 1024 640)}

# jpeg compression quality for static photos
jpeg_quality=${jpeg_quality:-85}

# Apply default sort directions if not set in config.sh
folder_sort_direction=${folder_sort_direction:-"asc"}
image_sort_direction=${image_sort_direction:-"asc"}

folder_sort_option="-r"
image_sort_option="-r"
if [ "$folder_sort_direction" = "asc" ]; then
  folder_sort_option=""
fi
if [ "$image_sort_direction" = "asc" ]; then
  image_sort_option=""
fi

# script starts here

command -v exiftool >/dev/null 2>&1 || { echo "EXIFTool is a required dependency, aborting..." >&2; exit 1; }
command -v vips >/dev/null 2>&1 || { echo "vips is a required dependency, aborting..." >&2; exit 1; }
command -v rsync >/dev/null 2>&1 || { echo "rsync is a required dependency, aborting..." >&2; exit 1; }

if $draft
then
	echo "setting up draft mode"
	# for a quick draft, use lowest resolution, fastest encode rates etc.
	resolution=(1024)
fi

# directory structure will form nav structure
paths=() # relevant non-empty dirs in $in_dir
nav_name=() # a front-end friendly label for each item in paths[], with numeric prefixes stripped
nav_depth=() # depth of each navigation item
nav_type=() # 0 = structure, 1 = leaf. Where a leaf directory is a gallery of images
nav_url=() # a browser-friendly url for each path, relative to output
nav_count=() # the number of images in each gallery, or -1 if not a leaf

metadata_file="metadata.txt" # search for this file in each gallery directory for gallery-wide metadata

gallery_files=() # a flat list of all gallery images
gallery_nav=() # index of nav item the gallery image belongs to
gallery_url=() # url-friendly name of each image
gallery_md5=() # md5 hash of original image 
gallery_maxwidth=() # maximum image size available
gallery_maxheight=() # maximum height

# scan working directory to populate $nav variables
root_depth=$(echo "$in_dir" | awk -F"/" "{ print NF }")

# $1: template, $2: {{ variable name }}, $3: replacement string
template () {
	key=$(echo "$2" | tr -d '[:space:]')
		
	value=$(echo $3 | sed -e 's/\\/\\\\/g' -e 's/\//\\\//g' -e 's/&/\\\&/g') # escape sed input
	echo "$1" | sed "s/{{$key}}/$value/g; s/{{$key:[^}]*}}/$value/g"
}

tmpdir=$(mktemp -d -p /tmpfs -t expose.XXXXXXXX)

if [ -z "$tmpdir" ]
then
	echo "Could not create scratch directory" >&2; exit 1;
fi

chmod -R 740 "$tmpdir"

printf "temp directory: $tmpdir\n"

cleanup() {
	echo "Cleaning up"
	
	if [ -d "$tmpdir" ]
    then
        rm -r "$tmpdir"
    fi
	
	echo "    done"
	echo "Elapsed time: $SECONDS seconds"  # Prints the time elapsed since SECONDS was initialized
	exit
}

trap cleanup INT TERM

printf "\nScanning directories\n    "

while read node
do
	printf "."

	node_depth=$(echo "$node" | awk -F"/" "{ print NF-$root_depth }")
	
	# ignore empty directories
	if find "$node" -maxdepth 0 -empty | read v
	then
		continue
	fi
	
	node_name=$(basename "$node" | sed -e 's/^[0-9]*//' | sed -e 's/^[[:space:]]*//;s/[[:space:]]*$//')
	if [ -z "$node_name" ]
	then
		node_name=$(basename "$node")
	fi
		
	dircount=$(find "$node" -maxdepth 1 -type d ! -path "$node" ! -path "$node*/_*" | wc -l)
	
	if [ "$dircount" -gt 0 ]
	then

		node_type=0 # dir contains other dirs, it is not a leaf
	else
		
		node_type=1 # does not contain other dirs, it is a leaf
	fi
	
	paths+=("$node")
	nav_name+=("$node_name")
	nav_depth+=("$node_depth")
	nav_type+=("$node_type")
done < <(find "$in_dir" -type d ! -path "$in_dir" ! -path "$in_dir*/_*" | sort $folder_sort_option)

# re-create directory structure
mkdir -p "$out_dir"

dir_stack=()
url_rel=""

printf "\n    done\nPopulating nav\n    "

for i in "${!paths[@]}"
do
	printf "."
	
	path="${paths[i]}"
	if [ "$i" -gt 1 ]
	then	
		if [ "${nav_depth[i]}" -gt "${nav_depth[i-1]}" ]
		then
			# push onto stack when we go down a level
			dir_stack+=("$url_rel")
		elif [ "${nav_depth[i]}" -lt "${nav_depth[i-1]}" ]
		then
			# pop stack with respect to current level
			diff="${nav_depth[i-1]}"
			while [ "$diff" -gt "${nav_depth[i]}" ]
			do
				unset dir_stack[${#dir_stack[@]}-1]
				((diff--))
			done
		fi
	fi
	
	url_rel=$(echo "${nav_name[$i]}" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]')
	
	url=""
	for u in "${dir_stack[@]}"
	do
		url+="$u/"
	done
	
	url+="$url_rel"
	mkdir -p "$out_dir/$url"
	nav_url+=("$url")
done

printf "\n    done\nReading files"

# read in each file to populate $gallery variables
for i in "${!paths[@]}"
do
	nav_count[i]=-1
	if [ "${nav_type[i]}" -lt 1 ]
	then
		continue
	fi
	
	dir="${paths[i]}"
	name="${nav_name[i]}"
	url="${nav_url[i]}"

	printf "\n    $url"

	mkdir -p "$out_dir"/"$url"

	index=0

	# loop over found files
	while read file
	do
		
		filename=$(basename "$file")
		filedir=$(dirname "$file")
		filepath="$file"
		
		printf "\n        $filename"
		
		trimmed=$(echo "${filename%.*}" | sed -e 's/^[[:space:]0-9]*//;s/[[:space:]]*$//')
		
		if [ -z "$trimmed" ]
		then
			trimmed=$(echo "${filename%.*}")
		fi
		
		image_url=$(echo "$trimmed" | sed 's/[^ a-zA-Z0-9]//g;s/ /-/g' | tr '[:upper:]' '[:lower:]')
		
		extension=$(echo "${filename##*.}" | tr '[:upper:]' '[:lower:]')
	
		# we'll trust that extensions aren't lying
		if [ "$extension" = "jpg" ] || [ "$extension" = "jpeg" ] || [ "$extension" = "png" ] || [ "$extension" = "gif" ]
		then
			format="$extension"
		else
			continue # not image, ignore
		fi	
		
		
		image="$file"
		
		# Get the width of the image
		width=$(vipsheader -f width "$image")
		# Get the height of the image
		height=$(vipsheader -f height "$image")

		maxwidth=0
		maxheight=0
		count=0
		
		for res in "${resolution[@]}"
		do
			((count++))
			# store max values for later use
			if [ "$width" -ge "$res" ] && [ "$res" -gt "$maxwidth" ]
			then
				maxwidth="$res"
				maxheight=$((res*height/width))
			elif [ "$maxwidth" -eq 0 ] && [ "$count" = "${#resolution[@]}" ]
			then
				maxwidth="$res"
				maxheight=$((res*height/width))
			fi
		done
				
		((index++))
		
		# store file and type for later use
		mdx=`md5sum "$file" | head -c 10`
		gallery_files+=("$file")
		gallery_nav+=("$i")
		gallery_url+=("$image_url")
		gallery_md5+=("$mdx")
		gallery_maxwidth+=("$maxwidth")
		gallery_maxheight+=("$maxheight")

	done < <(find "$dir" -maxdepth 1 ! -path "$dir" ! -path "$dir*/_*" | sort $image_sort_option)
	
	nav_count[i]="$index"
	
done

printf "\n    done"

# build html file for each gallery
template=$(cat "$theme_dir/template.html")
post_template=$(cat "$theme_dir/post-template.html")
nav_template=$(cat "$theme_dir/nav-template.html")

gallery_index=0
firsthtml=""
firstpath=""

printf "\nBuilding HTML"

for i in "${!paths[@]}"
do
	if [ "${nav_type[i]}" -lt 1 ]
	then
		continue
	fi

	printf "\n    ${nav_url[i]}"
	
	html="$template"
	
	gallery_metadata=""
	if [ -e "${paths[i]}/$metadata_file" ]
	then
		gallery_metadata=$(cat "${paths[i]}/$metadata_file")
	fi
	
	j=0
	while [ "$j" -lt "${nav_count[i]}" ]
	do	
		k=$((j+1))
		file_path="${gallery_files[gallery_index]}"
		
		# try to find a text file with the same name
		filename=$(basename "$file_path")
		printf "\n        $filename" # show progress
		
		filename="${filename%.*}"

		filedir=$(dirname "$file_path")
				
		if [ ! -e "$topdir/.cache/$project" ]
		then
			mkdir -p "$topdir/.cache/$project"
		fi

		textfile=$(find "$in_dir/$filename".txt "$in_dir/$filename".md ! -path "$file_path" -print -quit 2>/dev/null)
		
		metadata=""
		content=""
		if [ ! -e "$topdir/.cache/$project/${gallery_md5[gallery_index]}" ]
		then
			if LC_ALL=C file "$textfile" | grep -q text
			then
				# if there are two lines "---", the lines preceding the second "---" are assumed to be metadata
				text=$(cat "$textfile" | tr -d $'\r')
				text=${text%$'\n'}
				metaline=$(echo "$text" | grep -n -m 2 -- "^---$" | tail -1 | cut -d ':' -f1)
							
				if [ "$metaline" ]
				then
					sumlines=$(echo "$text" | wc -l)
					taillines=$((sumlines-metaline))
					
					metadata=$(head -n "$metaline" "$textfile")
					content=$(tail -n "$taillines" "$textfile")
				else
					metadata=""
					content=$(echo "$text")
				fi
			fi
			
			exif_metadata=""
			exif_metadata=$(exiftool -s2 "$file_path" | sed 's/\: /:/g' | sed 's/^/exif_/')

			metadata+=$'\n'
			metadata+="$gallery_metadata"
			metadata+=$'\n'
			metadata+="$exif_metadata"
			metadata+=$'\n'
			
			# if perl available, pass content through markdown parser
			if command -v perl >/dev/null 2>&1
			then
				content=$(perl "$scriptdir/markdown/markdown.pl" --html4tags <(echo "$content"))
			fi
			
			# write to post template
			post=$(template "$post_template" index "$k")
			
			post=$(template "$post" post "$content")
			
			while read line
			do
				key=$(echo "$line" | cut -d ':' -f1 | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
				value=$(echo "$line" | cut -d ':' -f2- | tr -d $'\r\n' | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
				colon=$(echo "$line" | grep ':')

				if [ "$key" ] && [ "$value" ] && [ "$colon" ]
				then
					if [ "$key" = "exif_LensModel" ]; then
						value=$(echo $value | sed 's/ (.*)//')
					elif [ "$key" = "exif_Model" ]; then
						value=$(echo $value| sed -e 's/ILCE-7M4/α 7 IV/' -e 's/ILCE-7M3/α 7 III/' -e 's/ILCE-7M2/α 7 II/' -e 's/ILCE-7/α 7/' -e 's/ILCE-7RM5/α 7R V/' -e 's/ILCE-7RM4/α 7R IV/' -e 's/ILCE-7RM3/α 7R III/' -e 's/ILCE-7RM2/α 7R II/' -e 's/ILCE-7R/α 7R/' -e 's/ILCE-7SM3/α 7S III/' -e 's/ILCE-7SM2/α 7S II/' -e 's/ILCE-7S/α 7S/')
					fi
					post=$(template "$post" "$key" "$value")
				fi
			done < <(echo "$metadata")
			
			# set image parameters
			post=$(template "$post" imagemd5 "${gallery_md5[gallery_index]}") 
			post=$(template "$post" imageurl "${gallery_url[gallery_index]}")
			post=$(template "$post" imagewidth "${gallery_maxwidth[gallery_index]}")
			
			post=$(template "$post" imageheight "${gallery_maxheight[gallery_index]}")
			
			echo "$post" > "$topdir/.cache/$project/${gallery_md5[gallery_index]}"

		else
			post=$(cat "$topdir/.cache/$project/${gallery_md5[gallery_index]}")
		fi

		html=$(template "$html" content "$post {{content}}" true)
		
		((gallery_index++))
		((j++))
	done
	
	#write html file
	html=$(template "$html" sitetitle "$site_title")
	html=$(template "$html" sitecopyright "$site_copyright")
	html=$(template "$html" navtitle "$nav_title")
	html=$(template "$html" gallerytitle "${nav_name[i]}")
		
	resolutionstring=$(printf "%s " "${resolution[@]}")
	html=$(template "$html" resolution "$resolutionstring")
			
	# build main navigation
	navigation=""
	
	# write html menu via depth first search
	depth=1
	prevdepth=0
	
	remaining="${#paths[@]}"
	parent=-1
	
	while [ "$remaining" -gt 0 ]
	do
		for j in "${!paths[@]}"
		do
			if [ "$depth" -gt 1 ] && [ "${nav_depth[j]}" = "$prevdepth" ]
			then
				parent="$j"
			fi
			
			if [ "$i" = "$j" ]
			then
				active="active"
			else
				active=""
			fi
			
			if [ "$parent" -lt 0 ] && [ "${nav_depth[j]}" = 1 ]
			then
				if [ "${nav_type[j]}" = 0 ]
				then
					navigation+="<li><span class=\"label\">${nav_name[j]}</span><ul>{{marker$j}}</ul></li>"
				else
					gindex=0
					for k in "${!gallery_nav[@]}"
					do
						if [ "${gallery_nav[k]}" = "$j" ]
						then
							gindex="$k"
							break
						fi
					done
					naventry=$(template "$nav_template" uri "{{basepath}}${nav_url[j]}")
					naventry=$(template "$naventry" text "${nav_name[j]}")
					naventry=$(template "$naventry" active "$active")
					naventry=$(template "$naventry" index "$j")
					naventry=$(template "$naventry" image "${gallery_url[gindex]}")
					navigation+=$naventry
				fi
				((remaining--))
			elif [ "${nav_depth[j]}" = "$depth" ]
			then
				if [ "${nav_type[j]}" = 0 ]
				then
					substring="<li><span class=\"label\">${nav_name[j]}</span><ul>{{marker$j}}</ul></li>{{marker$parent}}"
				else
					gindex=0
					for k in "${!gallery_nav[@]}"
					do
						if [ "${gallery_nav[k]}" = "$j" ]
						then
							gindex="$k"
							break
						fi
					done
					substring="<li class=\"gallery $active\" data-image=\"${gallery_url[gindex]}\"><a href=\"{{basepath}}${nav_url[j]}\"><span>${nav_name[j]}</span></a><ul>{{marker$j}}</ul></li>{{marker$parent}}"
				fi
				navigation=$(template "$navigation" "marker$parent" "$substring")
				((remaining--))
			fi
		done
		((prevdepth++))
		((depth++))
	done
	
	html=$(template "$html" navigation "$navigation")
	
	if [ -z "$firsthtml" ]
	then
		firsthtml="$html"
		firstpath="${nav_url[i]}"
	fi
	
	if [ "${nav_depth[i]}" = 0 ]
	then
		basepath="./"
	else
		basepath=$(yes "../" | head -n ${nav_depth[i]} | tr -d '\n')
	fi
	
	html=$(template "$html" basepath "$basepath")
	
	# set default values for {{XXX:default}} strings
	html=$(echo "$html" | sed "s/{{[^{}]*:\([^}]*\)}}/\1/g")
	
	# remove references to any unused {{xxx}} template variables and empty <ul>s from navigation
	html=$(echo "$html" | sed "s/{{[^}]*}}//g; s/<ul><\/ul>//g")

	printf "\n        Write index.html"
	
	echo "$html" > "$out_dir/${nav_url[i]}"/index.html
done

printf "\n    done"

printf "\nWrite top level index.html"

basepath="./"
firsthtml=$(template "$firsthtml" basepath "$basepath")
firsthtml=$(template "$firsthtml" resourcepath "$firstpath/")
firsthtml=$(echo "$firsthtml" | sed "s/{{[^{}]*:\([^}]*\)}}/\1/g")
firsthtml=$(echo "$firsthtml" | sed "s/{{[^}]*}}//g; s/<ul><\/ul>//g")
echo "$firsthtml" > "$out_dir"/index.html

printf "\n    done"
printf "\nStarting encode\n"

# resize images
for i in "${!gallery_files[@]}"
do
    navindex="${gallery_nav[i]}"
    url="${nav_url[navindex]}/${gallery_url[i]}"

    echo -n "    ${nav_url[navindex]} - ${gallery_url[i]}"
    
    mkdir -p "$out_dir/$url"
    
    image="${gallery_files[i]}"
            
	mkdir -p /$tmpdir/$url/

	# Copy the image to temp directory (in memory)
	vips copy "$image" "/$tmpdir/$url/source_image.v"
	source_width=$(vipsheader -f width "/$tmpdir/$url/source_image.v")
    
	# Loop through the resolutions and create resized images
    for res in "${resolution[@]}"
    do
		(
			output_file="$out_dir/$url/$res.jpg"
			if [ -e "$output_file" ]; then
				echo -n " »"
				continue
			fi

			# Calculate the scale factor
			scale_factor=$(echo "$res / $source_width" | bc -l)
			
			# Resize the image using the width
			vips resize "/$tmpdir/$url/source_image.v" "/$tmpdir/$url/resized_image_$res.v" $scale_factor
			vips jpegsave "/$tmpdir/$url/resized_image_$res.v" "$out_dir/$url/$res.jpg" --Q $jpeg_quality --optimize-coding --strip

			echo -n " ■"
		) &
    done
	# Wait for all background processes to finish
	wait

	# Check if the process was successful
	if [ $? -ne 0 ]; then
		echo -e " ✘"
		continue
	fi

	echo -e " ✔"
        
    rm -rf "$tmpdir/$url"
done


printf "Copying resources"
# copy resources to output
rsync -av --exclude="template.html" --exclude="post-template.html" --exclude="nav-template.html" --exclude="config.sh" "$theme_dir/" "$out_dir/" >/dev/null

printf "\n    done\n"

cleanup
