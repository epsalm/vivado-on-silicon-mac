#!/bin/zsh
# Config
DOCKER_IMAGE=vivado-x64
LOGO_IMG_FALLBACK="$HOME/.tools/vivado-on-silicon-mac/vivado_logo.png"
VIVADO_APP="Vivado.app"

# echo with color
function f_echo {
	echo -e "\e[1m\e[33m$1\e[0m"
}

script_dir=$(dirname -- "$(readlink -nf $0)";)

# check internet connectivity
if ! ping -q -c1 google.com &>/dev/null; then
	f_echo "Could not connect to the internet. Recheck and run ./install again."
	exit 1
fi

# check if Docker is installed
if ! [ -d "/Applications/Docker.app" ]; then
    f_echo "You need to install Docker first."
    exit 1
fi

# check if XQuartz is installed
if ! [ -d "/Applications/Utilities/XQuartz.app" ]; then
    f_echo "You need to install XQuartz first."
    exit 1
fi

# change XQuartz settings, otherwise no X11 connection from container possible
defaults write org.xquartz.X11 no_auth 1
defaults write org.xquartz.X11 nolisten_tcp 0
# Vivado seems to be using GLX
defaults write org.xquartz.X11 enable_iglx -bool true

# Launch Docker daemon and XQuartz
f_echo "Launching Docker daemon and XQuartz..."
open -a XQuartz

# Wait for docker to start
while ! docker ps &> /dev/null; do
	open -a Docker
	sleep 5
done

# Build the Docker image according to the dockerfile
f_echo "Building Docker image"
docker build --platform=linux/amd64 -t $DOCKER_IMAGE .

# Copy Vivado installation file into $script_dir
installation_binary=""
while ! [[ $installation_binary == *.bin ]]; do
	f_echo "Drag and drop the installation binary into this terminal window and press Enter: "
	read installation_binary
done
cp $installation_binary $script_dir

# Running install script in docker container
f_echo "Launching Docker container and installation script"
/usr/local/bin/docker run -it --init --rm --mount type=bind,source="/tmp/.X11-unix",target="/tmp/.X11-unix" --mount type=bind,source="$script_dir",target="/home/user" --platform linux/amd64 $DOCKER_IMAGE bash /home/user/docker.sh

# Create App icon
f_echo "Generating App icon"
LOGO_IMG=$(find Xilinx/Vivado/*/doc/images/vivado_logo.png)
if [ -z $LOGO_IMG ]; then
    LOGO_IMG=$LOGO_IMG_FALLBACK
fi
mkdir icon.iconset
sips -z 16 16 "$LOGO_IMG" --out "icon.iconset/icon_16x16.png"
sips -z 32 32 "$LOGO_IMG" --out "icon.iconset/icon_16x16@2x.png"
sips -z 32 32 "$LOGO_IMG" --out "icon.iconset/icon_32x32.png"
sips -z 64 64 "$LOGO_IMG" --out "icon.iconset/icon_32x32@2x.png"
sips -z 128 128 "$LOGO_IMG" --out "icon.iconset/icon_128x128.png"
sips -z 256 256 "$LOGO_IMG" --out "icon.iconset/icon_128x128@2x.png"
sips -z 256 256 "$LOGO_IMG" --out "icon.iconset/icon_256x256.png"
sips -z 512 512 "$LOGO_IMG" --out "icon.iconset/icon_256x256@2x.png"
sips -z 512 512 "$LOGO_IMG" --out "icon.iconset/icon_512x512.png"
iconutil -c icns icon.iconset
rm -rf icon.iconset
mv icon.icns $VIVADO_APP/Contents/Resources/icon.icns

# Create Launch_Vivado script; needed for getting script path
# Launch XQuartz and Docker
echo '#!/bin/zsh\nopen -a XQuartz\nopen -a Docker\nwhile ! /usr/local/bin/docker ps &> /dev/null; do\nopen -a Docker\nsleep 5\ndone\nwhile ! [ -d "/tmp/.X11-unix" ]; do\nopen -a XQuartz\nsleep 5\ndone\n' > $VIVADO_APP/Launch_Vivado
# Run docker container by starting hw_server first to establish an XVC connection and then Vivado
echo "/usr/local/bin/docker run --init --rm --name vivado_container --mount type=bind,source=\"/tmp/.X11-unix\",target=\"/tmp/.X11-unix\" --mount type=bind,source=\""$script_dir"\",target=\"/home/user\" --platform linux/amd64 $DOCKER_IMAGE sudo -H -u user bash /home/user/start_vivado.sh &" >> $VIVADO_APP/Launch_Vivado
# Launch XVC server on host
echo "osascript -e 'tell app \"Terminal\" to do script \" while "'!'" [[ \$(ps aux | grep vivado_container | wc -l | tr -d \\\"\\\\\\\n\\\\\\\t \\\") == \\\"1\\\" ]]; do "$script_dir"/xvcd/bin/xvcd; sleep 1; done; exit\"'" >> $VIVADO_APP/Launch_Vivado
chmod +x $VIVADO_APP/Launch_Vivado

