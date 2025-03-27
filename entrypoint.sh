#!/bin/bash
set -e

# GNU GENERAL PUBLIC LICENSE
# Version 3, 29 June 2007
#
# Copyright (C) 2025 authors
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program. If not, see <https://www.gnu.org/licenses/>.

# Make sure .bashrc is sourced
. /root/.bashrc

echo "Run pullhero"
pullhero --pullhero-github-api-token $GITHUB_TOKEN \
         --pullhero-action $PULLHERO_ACTION \
         --pullhero-review-action $PULLHERO_REVIEW_ACTION \
         --llm-api-host $LLM_API_HOST \
         --llm-api-key $LLM_API_KEY \
         --llm-api-model $LLM_API_MODEL || true
