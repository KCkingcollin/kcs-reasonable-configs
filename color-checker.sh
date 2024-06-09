# this will check for color changes in hyprland configs and apply them globally with the castle-shell config
#
rgb2hex() {                    
  R=$1
  G=$2
  B=$3
  printf "%02x" "$((R*256*256 + G*256 + B))"
}

num2css() {
    R=$1
    G=$2
    B=$3
    printf "$R, $G, $B"
}

outPrime=$(head -n 1 "$HOME"/.config/castle-shell/accent-color)
outAlt=$(head -n 2 "$HOME"/.config/castle-shell/accent-color | tail -1)
hexPrime=$(echo $(rgb2hex $outPrime))
hexAlt=$(echo $(rgb2hex $outAlt))
cssPrime=$(echo $(num2css $outPrime))
cssAlt=$(echo $(num2css $outAlt))

hyprlandPrimeColor="rgba("$hexPrime"a6)"
hyprlandAltColor="rgba("$hexAlt"8c)"
cssPrimeColor="rgba("$cssPrime", 0.5)"
cssAltColor="rgba("$cssAlt", 0.35)"
cssAltDarkColor="rgba("$cssAlt", 0.45)"
cssAltDarkerColor="rgba("$cssAlt", 0.6)"

hyprVar1=$(grep "col.active_border =" "$HOME"/.config/hypr/custom/looks.conf)
hyprVar2=$(grep "col.inactive_border =" "$HOME"/.config/hypr/custom/looks.conf)
hyprVar3=$(grep "col.active =" "$HOME"/.config/hypr/custom/looks.conf)
hyprVar4=$(grep "col.inactive =" "$HOME"/.config/hypr/custom/looks.conf)

sed -i "s/$hyprVar1/    col.active_border = $hyprlandPrimeColor/g" ~/.config/hypr/custom/looks.conf
sed -i "s/$hyprVar2/    col.inactive_border = $hyprlandAltColor/g" ~/.config/hypr/custom/looks.conf
sed -i "s/$hyprVar3/	     col.active = $hyprlandPrimeColor/g" ~/.config/hypr/custom/looks.conf
sed -i "s/$hyprVar4/	     col.inactive = $hyprlandAltColor/g" ~/.config/hypr/custom/looks.conf

echo "@define-color primaryColor $cssPrimeColor;
@define-color secondaryColor $cssAltColor;
@define-color secondaryColorDark $cssAltDarkColor;
@define-color secondaryColorDarker $cssAltDarkerColor;
@define-color textColor rgba(255, 255, 255, 1);" > "$HOME"/.config/castle-shell/colors.css

echo "* {
    primaryColor: $cssPrimeColor;
    secondaryColor: $cssAltColor;
    secondaryColorDark: $cssAltDarkColor;
    secondaryColorDarker: $cssAltDarkerColor;
    textColor: rgba(255, 255, 255, 1);
}" > "$HOME"/.config/castle-shell/colors.rasi

echo $cssPrimeColor
echo $cssAltColor
echo $cssAltDarkColor
echo $cssAltDarkerColor
echo $hyprlandPrimeColor
echo $hyprlandAltColor
