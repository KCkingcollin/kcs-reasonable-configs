displayManager="$(systemctl status display-manager | grep -m 1 .service | cut -d '.' -f 1 | cut -d ' ' -f2-)"
if [ "$displayManager" != "gdm" ];
then
    systemctl disable --now "$displayManager"
    systemctl enable --now gdm
else
    systemctl restart gdm
fi
