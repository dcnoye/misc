### D.C. Noye
### loop over macports that need to be forced to activate
### resulting from mixing pip install and port install 


if [ "$EUID" -ne 0 ]; then
  echo "Use sudo or run as root"
  exit
fi
target="$1"
while true;
do
    echo trying to install "$target"
    if [[ $(port installed "$target" | grep "$target") ]]; then 
	    echo "$target" present;
	    break;
    fi
    if [[ $(port -y install "$target" | grep Error) ]]; then 
	    echo "$target" not found;
	    break;
    fi

    line=`port -N install "$target" 2>&1 > /dev/tty | grep "port -f activate"`
    package=$(echo $line | sed -e "s/^.*port -f activate //" -e "s/. .*//")

    if [ "$package" = "$opackage" ]; then 
	    echo  "$package";
	    break;
    fi

    opackage="$package"
    echo activating "$package"
    port -f activate "$package"
done
