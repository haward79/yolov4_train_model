# What's this
A short script to setup Yolo v4 Tiny for model training. There is also a pre-trained model provided for person, dog, and cat detection.

# Pre-requirements
Please install Yolo v4 from [this repo](https://github.com/haward79/yolov4_installer).
Please install *python3-pip* by *apt* or other software management tools.

If all things get ready, you can download this project and run *yolo_train_setup.bash* .
For more information, please refer to *Usage section*.

# Usage
1. Download this project.

```
git clone 'https://github.com/haward79/yolov4_train_model'
cd yolov4_train_model
```

2. Modify *yolo_train_setup.bash* and *yolov4-tiny-obj.cfg* to fit your need.

```
# You can edit the following content in yolo_train_setup.bash

# Define constant (by user).
export kSampleNum=20
export kObjectNames=('person' 'dog' 'cat')
```

```
# You can take reference from https://github.com/AlexeyAB/darknet#how-to-train-tiny-yolo-to-detect-your-custom-objects
# and edit yolov4-tiny-obj.cfg
```

3. Please ensure the user has privilege to run the scripts.

```
chmod u+x *.bash
```

4. Run the setup script  
   Have a cup of coffee and take a rest !

```
./yolo_train_setup.bash
```

1. Run the following script to train the model

```
cd build/darknet/x64
./darknet detector train data/obj.data cfg/yolov4-tiny-obj.cfg yolov4-tiny.conv.29 -dont_show 2>&1 | tee train.log
```

# Changelog
- 10/10 2021
    1. First commit.

# Copyright
These scripts are written by [haward79](https://www.haward79.tw/).
They are free to use for both education and business.

