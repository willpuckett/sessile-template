#!/usr/bin/env bash

# This is a script to build ZMK locally on MacOS. You'll need to [install ZMK](https://zmk.dev/docs/development/local-toolchain/setup/native) first. 
# It is much easier to use the github action which will just work when you push the repo, but it is a little slower if you're doing lots of frequent builds. You can also make changes in the gui (zmk studio).
# Extra modules need to be installed before running this script, by git cloning them into ~/Public. 

# There is an [experimental build script](https://zmk.dev/docs/user-setup-cli) that might save some time, but I haven't tried it yet.

# ```
# cd ~/Public
# gh repo clone urob/zmk-auto-layer
# gh repo clone urob/zmk-helpers
# gh repo clone ssbb/zmk-antecedent-morph
# ```


pristine=false

while getopts ":p" opt; do
    case ${opt} in
        p )
            pristine=true
            ;;
        \? )
            echo "Usage: $0 [options]"
            echo "Options:"
            echo "  -p  pristine build (defaults to incremental)"
            exit 1
            ;;
    esac
done

home=$(echo ~)
project=$(pwd)
out="$project/out"
[[ -d $out ]] || mkdir "$out"

json=$(yq .include "$project/build.yaml")
length=$(jq length <<< $json)

. ~/Public/zmk/.venv/bin/activate
cd ~/Public/zmk/app

declare -A jobs

for i in $(seq 0 $((--length))); do 
    build=(west build)
    [[ $pristine == true ]] && echo pristine && build+=(-p)
    job=$(jq -r .[$i] <<< $json )

    artifact=$(jq -r .\"artifact-name\" <<< $job )
    build+=(-d build/$artifact)

    board=$(jq -r .board <<< $job )
    build+=(-b $board)

    snippet=$(jq -r .snippet <<< $job )
    [[ $snippet != null ]] && build+=(-S $snippet)
    
    build+=(--)

    shield=$(jq -r .shield <<< $job )
    [[ $shield != null ]] && build+=(-DSHIELD=$shield)

    build+=(-DZMK_CONFIG=$home/Public/sessile/config)

    cmake=$(jq -r .\"cmake-args\" <<< $job )
    [[ $cmake != null ]] && build+=($cmake)

    build+=("-DZMK_EXTRA_MODULES=\"$home/Public/zmk-auto-layer;$home/Public/zmk-helpers;$home/Public/zmk-antecedent-morph\"")

    jobs[$artifact]="${build[@]}"

done

parallel {} > /dev/null ::: "${jobs[@]}"

for a in "${!jobs[@]}"; do
    cp "build/$a/zephyr/zmk.uf2" "$out/$a.uf2"
done

# west build -d build/left -b seeeduino_xiao_ble -S studio-rpc-usb-uart -- -DSHIELD=sessile_left -DZMK_CONFIG=$home/Public/sessile/config -DDTS_EXTRA_CPPFLAGS="-DLAYOUT=3;-DDIRECT" -DZMK_EXTRA_MODULES="$home/Public/zmk-auto-layer;$home/Public/zmk-helpers;$home/Public/zmk-antecedent-morph"