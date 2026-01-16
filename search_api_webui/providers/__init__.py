# Copyright (c) 2026 QUERIT PRIVATE LIMITED
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
# THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
# DEALINGS IN THE SOFTWARE.

import os
import yaml
from .generic import GenericProvider
from .querit import QueritSdkProvider

def load_providers(file_path='providers.yaml'):
    """
    Parses the YAML configuration file and instantiates the appropriate provider classes.
    
    Args:
        file_path (str): Path to the providers configuration file.
        
    Returns:
        dict: A dictionary mapping provider names to their initialized instances.
    """
    if not os.path.exists(file_path):
        print(f"Warning: Provider config file not found at {file_path}")
        return {}
        
    with open(file_path, 'r', encoding='utf-8') as f:
        configs = yaml.safe_load(f)

    providers = {}
    for name, conf in configs.items():
        conf['name'] = name
        provider_type = conf.get('type', 'generic')

        # Instantiate specific provider based on type or name
        if provider_type == 'querit_sdk':
            providers[name] = QueritSdkProvider(conf)
        else:
            providers[name] = GenericProvider(conf)

    return providers
