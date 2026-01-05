#!/bin/bash
# Hook para activar SN-BANNER post-login
[ -x /etc/SN/banner/banner.sh ] && /etc/SN/banner/banner.sh
