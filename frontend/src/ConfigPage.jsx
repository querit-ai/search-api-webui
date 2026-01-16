/*
 * Copyright (c) 2026 QUERIT PRIVATE LIMITED
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to
 * deal in the Software without restriction, including without limitation the
 * rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
 * sell copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { ArrowLeft, Key, Save, Server, Code, Trash2, Settings2 } from 'lucide-react';
import { Button } from './components/Button';
import { Input } from './components/Input';
import { Card } from './components/Card';
import { Badge } from './components/Badge';

function ConfigPage() {
    const navigate = useNavigate();
    const [providers, setProviders] = useState([]);
    const [selectedName, setSelectedName] = useState('');

    // Config States
    const [hasKey, setHasKey] = useState(false);
    const [apiKey, setApiKey] = useState('');

    // Advanced Settings
    const [apiUrl, setApiUrl] = useState('');
    const [limit, setLimit] = useState('10');
    const [language, setLanguage] = useState('en-US');

    const [currentDetails, setCurrentDetails] = useState(null);
    const [saving, setSaving] = useState(false);

    // Initial Load
    useEffect(() => {
        fetchProviders();
    }, []);

    const fetchProviders = () => {
        fetch('/api/providers')
            .then(res => res.json())
            .then(data => {
                setProviders(data);
                // If no selection yet, select the first one
                if (data.length > 0 && !selectedName) {
                    selectProvider(data[0].name, data);
                } else if (selectedName) {
                    // Refresh current selection status
                    const p = data.find(x => x.name === selectedName);
                    if (p) {
                        updateLocalState(p);
                    }
                }
            })
            .catch(console.error);
    };

    const selectProvider = (name, list = providers) => {
        setSelectedName(name);
        const p = list.find(x => x.name === name);
        updateLocalState(p);
    };

    const updateLocalState = (p) => {
        if (p) {
            setCurrentDetails(p.details);
            setHasKey(p.has_key);

            // If backend returns previously saved user settings, populate them
            if (p.user_settings) {
                setApiUrl(p.user_settings.api_url || '');
                setLimit(p.user_settings.limit || '10');
                setLanguage(p.user_settings.language || 'en-US');
            } else {
                // Reset to defaults if no config exists
                setApiUrl('');
                setLimit('10');
                setLanguage('en-US');
            }

            // Always clear API key input when switching/refreshing for security
            setApiKey('');
        }
    };

    const handleProviderChange = (e) => {
        selectProvider(e.target.value);
    };

    const handleDeleteKey = async () => {
        if (!confirm('Are you sure you want to remove the API Key?')) {
            return;
        }

        setSaving(true);
        try {
            // Sending empty key implies deletion
            await fetch('/api/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    provider: selectedName,
                    api_key: '', // Empty string to trigger delete in backend
                    // Keep other settings as they are, or reset them if you prefer
                    api_url: apiUrl,
                    limit: limit,
                    language: language
                })
            });
            alert('API Key removed.');
            fetchProviders();
        } catch (e) {
            alert('Failed to remove key.');
        } finally {
            setSaving(false);
        }
    };

    const handleSave = async () => {
        // Validation: If no key stored and input is empty, warn user
        if (!hasKey && !apiKey.trim()) {
            alert('Please enter an API Key.');
            return;
        }

        setSaving(true);
        try {
            const payload = {
                provider: selectedName,
                api_key: apiKey,
                api_url: apiUrl,
                limit: limit,
                language: language
            };

            if (hasKey && !apiKey) {
                alert('Please re-enter your API Key to save changes.');
                setSaving(false);
                return;
            }

            await fetch('/api/config', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            alert(`Configuration for ${selectedName} saved.`);
            setApiKey(''); // Clear input for security
            fetchProviders(); // Refresh status
        } catch (e) {
            alert('Save failed.');
        } finally {
            setSaving(false);
        }
    };

    return (
        <div className="min-h-screen bg-gray-50 p-6">
            <div className="max-w-2xl mx-auto">
                <Button
                    variant="ghost"
                    className="mb-6 pl-0 text-gray-500 hover:text-gray-900"
                    onClick={() => navigate('/')}
                >
                    <ArrowLeft className="w-4 h-4 mr-2" /> Back to Search
                </Button>

                <div className="space-y-6">
                    <div>
                        <h1 className="text-3xl font-bold text-gray-900">
                            Configuration
                        </h1>
                        <p className="text-gray-500 mt-2">
                            Manage API keys and advanced settings for search providers.
                        </p>
                    </div>

                    <Card className="p-6 space-y-8">
                        {/* Provider Selection */}
                        <div className="space-y-3">
                            <label className="text-sm font-medium flex items-center gap-2 text-gray-700">
                                <Server className="w-4 h-4" />
                                Select Provider
                            </label>
                            <select
                                value={selectedName}
                                onChange={handleProviderChange}
                                className="flex h-10 w-full items-center justify-between
                                    rounded-md border border-gray-200 bg-white px-3 py-2
                                    text-sm focus:outline-none focus:ring-2
                                    focus:ring-blue-600"
                            >
                                {providers.map(p => (
                                    <option key={p.name} value={p.name}>
                                        {p.name}
                                    </option>
                                ))}
                            </select>
                        </div>

                        <div className="border-t border-gray-100 my-4"></div>

                        {/* API Key Section */}
                        <div className="space-y-3">
                            <label className="text-sm font-medium flex items-center gap-2 text-gray-700">
                                <Key className="w-4 h-4" />
                                API Key
                            </label>

                            {hasKey ? (
                                <div
                                    className="flex items-center justify-between bg-green-50 border
                                        border-green-200 rounded-md px-3 py-2"
                                >
                                    <div className="flex items-center gap-2 text-green-800 font-mono text-sm">
                                        <span>********************</span>
                                        <Badge className="bg-green-200 text-green-800 hover:bg-green-300 border-0">
                                            Configured
                                        </Badge>
                                    </div>
                                    <Button
                                        variant="ghost"
                                        size="sm"
                                        onClick={handleDeleteKey}
                                        className="text-red-600 hover:text-red-700 hover:bg-red-50 h-8"
                                    >
                                        <Trash2 className="w-4 h-4 mr-1" /> Remove
                                    </Button>
                                </div>
                            ) : (
                                <div className="text-sm text-gray-500 mb-2">
                                    No API key configured. Please enter one below.
                                </div>
                            )}

                            {/* Input for New/Update Key */}
                            <Input
                                type="password"
                                placeholder={hasKey
                                    ? 'Enter API Key to update...'
                                    : `Enter API Key for ${selectedName}`}
                                value={apiKey}
                                onChange={(e) => setApiKey(e.target.value)}
                                className="font-mono"
                            />
                        </div>

                        <div className="border-t border-gray-100 my-4"></div>

                        {/* Advanced Settings */}
                        <div className="space-y-4">
                            <h3 className="text-sm font-semibold flex items-center gap-2 text-gray-900">
                                <Settings2 className="w-4 h-4" />
                                Advanced Settings
                            </h3>

                            <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
                                <div className="space-y-2 col-span-2">
                                    <label className="text-xs font-medium text-gray-600">
                                        API Base URL (Optional)
                                    </label>
                                    <Input
                                        placeholder="https://api.example.com/v1/search"
                                        value={apiUrl}
                                        onChange={(e) => setApiUrl(e.target.value)}
                                        className="font-mono text-sm"
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-xs font-medium text-gray-600">
                                        Result Limit
                                    </label>
                                    <Input
                                        type="number"
                                        placeholder="10"
                                        value={limit}
                                        onChange={(e) => setLimit(e.target.value)}
                                    />
                                </div>

                                <div className="space-y-2">
                                    <label className="text-xs font-medium text-gray-600">
                                        Language Code
                                    </label>
                                    <Input
                                        placeholder="en-US"
                                        value={language}
                                        onChange={(e) => setLanguage(e.target.value)}
                                    />
                                </div>
                            </div>
                        </div>

                        {/* Save Action */}
                        <div className="pt-4">
                            <Button onClick={handleSave} disabled={saving} className="w-full md:w-auto">
                                <Save className="w-4 h-4 mr-2" />
                                {saving ? 'Saving Configuration...' : 'Save Configuration'}
                            </Button>
                        </div>

                        {/* Technical Details (Read-only) */}
                        <div className="border-t pt-6 mt-6">
                            <div className="flex items-center justify-between mb-4">
                                <h3 className="text-sm font-semibold flex items-center gap-2 text-gray-900">
                                    <Code className="w-4 h-4" />
                                    Provider Specs (Read-only)
                                </h3>
                            </div>

                            <div className="bg-gray-900 rounded-lg p-4 overflow-x-auto shadow-inner">
                                {currentDetails ? (
                                    <pre className="text-xs text-gray-300 font-mono leading-relaxed">
                                        {JSON.stringify(currentDetails, null, 2)}
                                    </pre>
                                ) : (
                                    <p className="text-gray-500 text-sm">No details available</p>
                                )}
                            </div>
                        </div>
                    </Card>
                </div>
            </div>
        </div>
    );
}

export default ConfigPage;
