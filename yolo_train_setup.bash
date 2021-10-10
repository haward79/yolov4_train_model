#!/bin/bash

# Define constant (by user).
export kSampleNum=20
export kObjectNames=('person' 'dog' 'cat')

# Define constant (by script).
export kObjectNum=${#kObjectNames[@]}
export kObjectNameStr=''
export kObjectOldIds=()

for name in ${kObjectNames[@]}
do
	export kObjectNameStr="$kObjectNameStr,$name"
done

if [[ "$kObjectNameStr" != '' ]]
then
	export kObjectNameStr=$(echo "$kObjectNameStr" | cut -b 2-)
fi

# Main
echo 'This script should run in the root of darknet project.'
echo 'You can clone it from https://github.com/AlexeyAB/darknet.git'
echo ''
read -p 'Press ENTER to continue ......' trash
echo ''

if [[ -d 'build/darknet/x64' ]]
then
	cd 'build/darknet/x64'
	echo 'Notice: working directory changed to "build/darknet/x64"'
else
	echo 'Failed to change directory to "build/darknet/x64"'
	exit 1
fi

# Copy darknet binary file.
if [[ -f ../../../darknet ]]
then
	cp ../../../darknet .
else
	echo 'Can NOT locate darknet binary file.'
	echo 'Do you make the project ?'
	exit 1
fi

# Copy config file.
if [[ -f '../../../yolov4-tiny-obj.cfg' ]]
then
	cp '../../../yolov4-tiny-obj.cfg' 'cfg/'
else
	echo 'File "yolov4-tiny-obj.cfg" NOT found !'
	exit 1
fi

# Clear old content.
echo -n '' > 'data/obj.names'
echo -n '' > 'data/obj.data'

# Write content of obj.names .
for ((i=0; i<kObjectNum; ++i))
do
	echo "${kObjectNames[$i]}" >> data/obj.names
done

# Write content of obj.data .
echo -e "classes = $kObjectNum\ntrain  = data/train.txt\nvalid  = data/test.txt\nnames = data/obj.names\nbackup = backup/" > data/obj.data

# Install fiftyone by pip3.
if [[ "$(which fiftyone)" == '' ]]
then
    if [[ "$(which pip3)" == '' ]]
    then
        echo 'Please install python3-pip first !'
        exit 1
    else
        # Update pip3.
        pip3 install -U pip

        # Install fiftyone.
        pip3 install fiftyone

        # Check fiftyone.
        if [[ "$(which fiftyone)" == '' ]]
        then
            echo 'Failed to locate fiftyone.'
            echo 'Please install fiftyone manually and add it to $PATH.'
            exit 1
        fi
    fi
fi

# Remove old dataset.
if [[ -d 'data/yolov4_train' ]]
then
	echo 'Remove old dataset on disk.'
	rm -r 'data/yolov4_train'
fi

if [[ "$(fiftyone datasets list | grep -v yolov4_train_bak | grep yolov4_train)" != '' ]]
then
	echo 'Remove old dataset in fiftyone database.'
	fiftyone datasets delete yolov4_train
fi

# Download dataset.
if [[ -d 'data/yolov4_train.bak' ]]
then
	echo 'Dataset backup exists.'
	echo 'Restore backup ......'

	cp -r 'data/yolov4_train.bak' 'data/yolov4_train'

	# Check database of fiftyone.
	if [[ "$(fiftyone datasets list | grep yolov4_train_bak)" == '' ]]
	then
		echo 'Dataset backup does NOT in database. Addd it in now !'
		fiftyone datasets create -n 'yolov4_train_bak' -d 'data/yolov4_train.bak/' -t fiftyone.types.YOLOv4Dataset
	fi
else
	# Download coco2017 training dataset.
	fiftyone zoo datasets load coco-2017 -s train -n 'coco2017_train' -d 'data/coco2017_train' -k max_samples=$kSampleNum label_types=detections classes=person,cat,dog only_matching=True
	fiftyone datasets delete 'coco2017_train'

	# Convert coco2017 to yolov4.
	fiftyone convert --input-dir 'data/coco2017_train/train' --input-type fiftyone.types.COCODetectionDataset --output-dir 'data/yolov4_train' --output-type fiftyone.types.YOLOv4Dataset

	# Delete coco2017 dataset and do backup for yolov4 training dataset.
	rm -r 'data/coco2017_train'
	cp -r 'data/yolov4_train' 'data/yolov4_train.bak'

	if [[ "$(fiftyone datasets list | grep yolov4_train_bak)" != '' ]]
	then
		fiftyone datasets delete yolov4_train_bak
	fi

	fiftyone datasets create -n 'yolov4_train_bak' -d 'data/yolov4_train.bak/' -t fiftyone.types.YOLOv4Dataset
fi

# Get old id for classes.
export oldClassId=0

if [[ -f 'data/yolov4_train/obj.names' ]]
then
	while read item
	do
		for ((i=0; i<kObjectNum; ++i))
		do
			if [[ "$item" == "${kObjectNames[$i]}" ]]
			then
				kObjectOldIds[$i]=$oldClassId
			fi
		done

		# Increment id.
		export oldClassId=$(expr $oldClassId + 1)
	done < 'data/yolov4_train/obj.names'
else
	echo 'Failed to load "data/yolov4_train/obj.names" .'
	echo 'Failed to get ids for old classes.'
	exit 1
fi

if [[ ${#kObjectNames[@]} -ne ${#kObjectOldIds[@]} ]]
then
	echo 'Failed to load old id for all classes.'
	echo 'Some class may NOT in old class list'
	exit 1
fi

# Get new class list.
cp 'data/obj.names' 'data/yolov4_train/'

# Remove undefined class in yolo training dataset.
for filename in data/yolov4_train/data/*.txt
do
	export lines=$(cat "$filename")
	echo -n '' > "$filename"

	# Read content in file.
	echo "$lines" | while read line
	do
		# Fetch object id in $line.
		export objOldId=$(echo $line | cut -d ' ' -f 1)

		# Search class name.
		for ((i=0; i<kObjectNum; ++i))
		do
			if [[ "${kObjectOldIds[$i]}" == $objOldId ]]
			then
				echo -n "$i " >> "$filename"
				echo $(echo "$line" | cut -d ' ' -f 2-) >> "$filename"

				break
			fi
		done
	done
done

# Add yolov4 training dataset to fiftyone.
fiftyone datasets create -n 'yolov4_train' -d 'data/yolov4_train/' -t fiftyone.types.YOLOv4Dataset

# Create root of dataset saving directory for yolo training.
if [[ -d 'data/obj' ]]
then
	rm -r -f 'data/obj'
fi

mkdir 'data/obj'

if [[ $? -ne 0 ]]
then
	echo 'Failed to create directory "data/obj"'
	exit 1
fi

# Copy training dataset to specified folder for training.
cp 'data/yolov4_train/data/'* 'data/obj/'

# Create train.txt .
echo -n '' > 'data/train.txt'
find 'data/obj' -name '*.jpg' -exec echo "{}" >> 'data/train.txt' \;

# Download pre-trained weight.
if [[ -f 'yolov4-tiny.conv.29' ]]
then
	echo 'File "yolov4-tiny.conv.29" already exists. NOP!'
else
	wget --quiet 'https://github.com/AlexeyAB/darknet/releases/download/darknet_yolo_v4_pre/yolov4-tiny.conv.29'
fi

# Print training command.
echo ''
echo 'Please run the following command to start training.'
echo 'cd build/darknet/x64'
echo './darknet detector train data/obj.data cfg/yolov4-tiny-obj.cfg yolov4-tiny.conv.29 -dont_show 2>&1 | tee train.log'
echo ''
echo 'After training, remember to copy files to destination system:'
echo '    build/darknet/x64/cfg/yolov4-tiny-obj.cfg               ->  cfg/yolov4-tiny-obj.cfg'
echo '    build/darknet/x64/data/obj.data                         ->  data/obj.data'
echo '    build/darknet/x64/data/obj.names                        ->  data/obj.names'
echo '    build/darknet/x64/backup/yolov4-tiny-obj_final.weights  ->  yolov4-tiny-obj_final.weights'
echo ''

