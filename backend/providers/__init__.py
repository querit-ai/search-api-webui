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
        if name == 'querit' or provider_type == 'querit_sdk':
            providers[name] = QueritSdkProvider(conf)
        else:
            providers[name] = GenericProvider(conf)

    return providers
