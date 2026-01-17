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
import {
    Search,
    Settings,
    Loader2,
    ChevronDown,
    Clock,
    Database,
    AlertCircle,
    CheckCircle2,
    XCircle,
    Swords // 新增图标
} from 'lucide-react';
import { Button } from './components/Button';
import { Input } from './components/Input';
import { Card } from './components/Card';
import { Badge } from './components/Badge';
import { ResultItem } from './components/ResultItem';
import { cn } from './lib/utils';

function SearchPage() {
    const navigate = useNavigate();

    // State Management
    const [providers, setProviders] = useState([]);
    const [selectedProvider, setSelectedProvider] = useState('');
    const [hasKey, setHasKey] = useState(false);

    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [metrics, setMetrics] = useState(null);
    const [loading, setLoading] = useState(false);
    const [searched, setSearched] = useState(false);
    const [error, setError] = useState(null);

    // Initial Load
    useEffect(() => {
        fetch('/api/providers')
            .then((res) => res.json())
            .then((data) => {
                setProviders(data);
                if (data.length > 0) {
                    setSelectedProvider(data[0].name);
                }
            })
            .catch(console.error);
    }, []);

    // Monitor selection to update Key status
    useEffect(() => {
        if (selectedProvider && providers.length > 0) {
            const p = providers.find((item) => item.name === selectedProvider);
            setHasKey(p ? p.has_key : false);
        }
    }, [selectedProvider, providers]);

    const handleConfigClick = () => {
        navigate('/config');
    };

    const handleArenaClick = () => {
        navigate('/arena');
    };

    const handleProviderChange = (e) => {
        setSelectedProvider(e.target.value);
    };

    const handleQueryChange = (e) => {
        setQuery(e.target.value);
    };

    const handleSearch = async (e) => {
        e.preventDefault();
        if (!query.trim()) {
            return;
        }

        setLoading(true);
        setSearched(true);
        setResults([]);
        setMetrics(null);
        setError(null);

        try {
            const res = await fetch('/api/search', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    query: query,
                    provider: selectedProvider,
                }),
            });

            const data = await res.json();
            if (data.error) {
                setError(data.error);
            } else {
                setResults(data.results || []);
                setMetrics(data.metrics);
            }
        } catch (err) {
            setError('Network request failed. Please check the backend service.');
        } finally {
            setLoading(false);
        }
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-gray-50 to-blue-50 p-6">
            <div className="max-w-4xl mx-auto space-y-8">
                <div className="text-center space-y-2">
                    <h1
                        className={cn(
                            'text-4xl font-bold bg-gradient-to-r',
                            'from-blue-600 to-indigo-600 bg-clip-text text-transparent'
                        )}
                    >
                        Search API WebUI
                    </h1>
                </div>

                {/* Control Panel */}
                <Card className="p-6 shadow-md border-0 ring-1 ring-gray-200">
                    <form onSubmit={handleSearch} className="space-y-6">

                        {/* Top Row: Engine Selection & Status/Config */}
                        <div className="flex flex-col md:flex-row justify-between items-center gap-4">
                            {/* Left: Engine Selector */}
                            <div className="flex items-center gap-3 w-full md:w-auto">
                                <label className="text-sm font-medium text-gray-700 whitespace-nowrap">
                                    Engine
                                </label>
                                <div className="relative w-full md:w-64">
                                    <select
                                        className={cn(
                                            'flex h-12 w-full items-center',
                                            'justify-between rounded-md border',
                                            'border-gray-200 bg-white px-3 py-2',
                                            'text-sm ring-offset-background',
                                            'placeholder:text-gray-500',
                                            'focus:outline-none focus:ring-2',
                                            'focus:ring-blue-600',
                                            'disabled:cursor-not-allowed',
                                            'disabled:opacity-50',
                                            'appearance-none'
                                        )}
                                        value={selectedProvider}
                                        onChange={handleProviderChange}
                                    >
                                        {providers.map((p) => (
                                            <option key={p.name} value={p.name}>
                                                {p.name}
                                            </option>
                                        ))}
                                    </select>
                                    <ChevronDown
                                        className={cn(
                                            'absolute right-3 top-3.5 h-4 w-4',
                                            'opacity-50 pointer-events-none'
                                        )}
                                    />
                                </div>
                            </div>

                            {/* Right: Status Pill + Arena + Config Button */}
                            <div className="flex items-center gap-3">
                                {/* Status Pill */}
                                <div
                                    className={cn(
                                        'flex items-center gap-1.5 text-xs font-medium',
                                        'px-3 py-1.5 rounded-full border',
                                        hasKey
                                            ? 'bg-green-50 text-green-700 border-green-200'
                                            : 'bg-red-50 text-red-700 border-red-200'
                                    )}
                                >
                                    {hasKey ? (
                                        <CheckCircle2 className="w-3.5 h-3.5 text-green-600" />
                                    ) : (
                                        <XCircle className="w-3.5 h-3.5 text-red-600" />
                                    )}
                                    {hasKey ? 'Ready' : 'No API Key'}
                                </div>

                                {/* Arena Button */}
                                <Button
                                    type="button"
                                    variant="outline"
                                    size="icon"
                                    onClick={handleArenaClick}
                                    title="Enter API Arena"
                                    className="h-9 w-9 border-purple-200 text-purple-600 hover:bg-purple-50 hover:text-purple-700"
                                >
                                    <Swords className="w-4 h-4" />
                                </Button>

                                {/* Config Button */}
                                <Button
                                    type="button"
                                    variant="outline"
                                    size="icon"
                                    onClick={handleConfigClick}
                                    title="Configure Provider"
                                    className="h-9 w-9 border-gray-200 hover:bg-gray-100 hover:text-gray-900"
                                >
                                    <Settings className="w-4 h-4 text-gray-600" />
                                </Button>
                            </div>
                        </div>

                        {/* Bottom Row: Search Input & Action */}
                        <div className="flex flex-col md:flex-row gap-4 items-center">
                            <div className="w-full flex-1 space-y-2">
                                <Input
                                    className="h-12 text-lg"
                                    placeholder="Enter your search query..."
                                    value={query}
                                    onChange={handleQueryChange}
                                    autoFocus
                                />
                            </div>

                            <Button
                                type="submit"
                                size="lg"
                                className="h-12 px-8 flex-shrink-0"
                                disabled={loading}
                            >
                                {loading ? (
                                    <Loader2 className="w-5 h-5 animate-spin mr-2" />
                                ) : (
                                    <Search className="w-5 h-5 mr-2" />
                                )}
                                {loading ? 'Searching...' : 'Search'}
                            </Button>
                        </div>
                    </form>
                </Card>

                {/* Error Display */}
                {error && (
                    <div
                        className={cn(
                            'bg-red-50 border border-red-200 rounded-lg p-4',
                            'flex items-center gap-3 text-red-800'
                        )}
                    >
                        <AlertCircle className="w-5 h-5 text-red-600 flex-shrink-0" />
                        <p>{error}</p>
                    </div>
                )}

                {/* Results Area */}
                {searched && !loading && !error && (
                    <div
                        className={cn(
                            'space-y-6 animate-in fade-in',
                            'slide-in-from-bottom-4 duration-500'
                        )}
                    >
                        {/* Metrics Header */}
                        <div className="flex items-center justify-between border-b pb-2">
                            <h2 className="text-lg font-semibold text-gray-800">
                                Results
                                <span className="text-gray-400 font-normal text-sm ml-2">
                                    Found {results.length} items
                                </span>
                            </h2>
                            {metrics && (
                                <div className="flex gap-2">
                                    <Badge
                                        variant="outline"
                                        className="gap-1 text-gray-500"
                                    >
                                        <Clock className="w-3 h-3" />
                                        {metrics.latency_ms}ms
                                    </Badge>
                                    <Badge
                                        variant="outline"
                                        className="gap-1 text-gray-500"
                                    >
                                        <Database className="w-3 h-3" />
                                        {metrics.size_bytes} B
                                    </Badge>
                                </div>
                            )}
                        </div>

                        {/* Result List */}
                        {results.length > 0 ? (
                            <div className="grid gap-4">
                                {results.map((item, idx) => (
                                    <ResultItem key={item.url || idx} item={item} />
                                ))}
                            </div>
                        ) : (
                            <div
                                className={cn(
                                    'text-center py-12 bg-white rounded-lg',
                                    'border border-dashed border-gray-300'
                                )}
                            >
                                <Search className="w-12 h-12 text-gray-300 mx-auto mb-3" />
                                <p className="text-gray-500">No results found.</p>
                            </div>
                        )}
                    </div>
                )}
            </div>
        </div>
    );
}

export default SearchPage;
