#!/bin/sh
# Build script for boost

# Set script parameters
PACKAGE_NAME="boost"
DOWNLOAD_LINK="https://sourceforge.net/projects/boost/files/boost/1.83.0/boost_1_83_0.tar.gz"
PACKAGE_DIR_NAME="boost_1_83_0"


usage() {
    echo "usage: $0 [-h] [-d destination] [-s destination] [-b destination] [--make_arg argument] [--skip_download, --skip_build] [--clean_source]"
    echo "  -h, --help                      display this help message"
    echo "  -d, --dest destination          set the destination directory (containing source and build directories)"
    echo "  -s, --source destination        set the source destination directory"
    echo "  -b, --build destination         set the build destination directory"
    echo "  --make_arg argument             additional argument to be passed to make"
    echo "  --skip_download                 $PACKAGE_NAME exists pre-downloaded at the source destination"
    echo "  --skip_build                    $PACKAGE_NAME has already been built at the build destination"
    echo "  --clean_source                  remove source directory after build"
}


# Parse command line options
SKIP_DOWNLOAD=false
SKIP_BUILD=false
CLEAN_SOURCE=false
while [ "$1" != "" ]; do
    case $1 in
        -h | --help )
            usage
            exit
        ;;
        -d | --dest )
            shift
            DEST="$1"
        ;;
        -s | --source )
            shift
            SOURCE_DIR="$1"
        ;;
        -b | --build )
            shift
            BUILD_DIR="$1"
        ;;
        --skip_download )
            SKIP_DOWNLOAD=true
        ;;
        --skip_build )
            SKIP_BUILD=true
        ;;
        --make_arg )
            shift
            MAKE_ARG="$1"
        ;;
        --clean_source)
            CLEAN_SOURCE=true
        ;;
        * )
            usage
            exit 1
        ;;
    esac
    shift
done

if [ "$DEST" != "" ]; then
    if [ -z "$SOURCE_DIR" ]; then
        SOURCE_DIR="${DEST%/}/source/"
    fi
    if [ -z "$BUILD_DIR" ]; then
        BUILD_DIR="${DEST%/}/build/"
    fi
fi

if [ ! -d "$SOURCE_DIR" ]; then
    echo "Invalid source destination directory: $SOURCE_DIR"
    exit 2
fi
if [ ! -d "$BUILD_DIR" ]; then
    echo "Invalid build destination directory: $BUILD_DIR"
    exit 3
fi

# Download and unzip the package
cd "$SOURCE_DIR"
if [ $SKIP_DOWNLOAD = false ]; then
    echo "Downloading $PACKAGE_NAME to $SOURCE_DIR"
    wget "$DOWNLOAD_LINK" -O "$PACKAGE_DIR_NAME.tar.gz" || exit 11
    echo "Extracting $PACKAGE_NAME"
    mkdir "$PACKAGE_DIR_NAME"
    tar -xzf "$PACKAGE_DIR_NAME.tar.gz" -C "$PACKAGE_DIR_NAME" --strip-components=1 || exit 12
    rm "$PACKAGE_DIR_NAME.tar.gz"
fi

# Run package installation
if [ $SKIP_BUILD = false ]; then
    echo "Compiling $PACKAGE_NAME"
    cd "$PACKAGE_DIR_NAME"
    ./bootstrap.sh --without-libraries=python --prefix="${BUILD_DIR%/}" || exit 31
    echo "Installing $PACKAGE_NAME"
    
    # It is important in boost versions > 1.73 to check for make args
    # and to manually specify the number of cores to use (to 1)
    # in the case that the the user does not specify for us.
    # This is becuase in boost > 1.73, the default number of
    # jobs/threads used in the compile is set to the number of available cpu threads.
    # But the Boost manual warns us that "There are circumstances when that default can be larger 
    # than the allocated cpu resources, for instance in some virtualized container installs."
    # Because the buildbost for cvmfs is done in a container, we will run into a 
    # problem where the builder will try and use cores that are allocated outside
    # the container. So we must protect against this by having a "fall-back"
    # option where we allow it access to only 1 core, unless the user specifies otherwise.

    echo "make arg is $MAKE_ARG"

    if [ -z "$MAKE_ARG" ]
    then
        ./b2 -j 1
    else
        ./b2 "$MAKE_ARG"		
    fi
    ./b2 install
fi

# Clean up source directory if requested
if [ $CLEAN_SOURCE = true ]; then
    echo "Removing $PACKAGE_NAME source directory from $SOURCE_DIR"
    cd "$SOURCE_DIR"
    rm -rf "$PACKAGE_DIR_NAME"
fi

echo "$PACKAGE_NAME installed in $BUILD_DIR"