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
    ArrowLeft,
    Search,
    Zap,
    Database,
    Trophy,
    Loader2,
    AlertCircle
} from 'lucide-react';
import { Button } from './components/Button';
import { Input } from './components/Input';
import { Card } from './components/Card';
import { Badge } from './components/Badge';
import { ResultItem } from './components/ResultItem';
import { cn } from './lib/utils';

function ArenaPage() {
    const navigate = useNavigate();
    const [providers, setProviders] = useState([]);
    
    // Arena State
    const [leftProvider, setLeftProvider] = useState('');
    const [rightProvider, setRightProvider] = useState('');
    const [query, setQuery] = useState('');
    const [loading, setLoading] = useState(false);
    
    // Results State
    const [leftResult, setLeftResult] = useState(null);
    const [rightResult, setRightResult] = useState(null);

    // Initial Load
    useEffect(() => {
        fetch('/api/providers')
            .then((res) => res.json())
            .then((data) => {
                setProviders(data);
                if (data.length >= 2) {
                    setLeftProvider(data[0].name);
                    setRightProvider(data[1].name);
                } else if (data.length === 1) {
                    setLeftProvider(data[0].name);
                    setRightProvider(data[0].name);
                }
            })
            .catch(console.error);
    }, []);

    const performSearch = async (provider, queryText) => {
        try {
            const start = performance.now();
            const res = await fetch('/api/search', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query: queryText, provider: provider }),
            });
            const data = await res.json();
            const end = performance.now();
            
            // Client-side measured latency fallback if server doesn't provide it
            const clientLatency = Math.round(end - start);
            
            if (data.error) return { error: data.error };
            
            return {
                results: data.results || [],
                metrics: {
                    latency_ms: data.metrics?.latency_ms || clientLatency,
                    size_bytes: data.metrics?.size_bytes || 0
                }
            };
        } catch (err) {
            return { error: 'Network Error' };
        }
    };

    const handleCompare = async (e) => {
        e.preventDefault();
        if (!query.trim()) return;

        setLoading(true);
        setLeftResult(null);
        setRightResult(null);

        // Run in parallel
        const [res1, res2] = await Promise.all([
            performSearch(leftProvider, query),
            performSearch(rightProvider, query)
        ]);

        setLeftResult(res1);
        setRightResult(res2);
        setLoading(false);
    };

    return (
        <div className="min-h-screen bg-gray-50 flex flex-col">
            {/* Header */}
            <div className="bg-white border-b sticky top-0 z-10">
                <div className="max-w-7xl mx-auto px-4 h-16 flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <Button variant="ghost" size="icon" onClick={() => navigate('/')}>
                            <ArrowLeft className="w-5 h-5 text-gray-600" />
                        </Button>
                        <h1 className="text-xl font-bold bg-gradient-to-r from-purple-600 to-blue-600 bg-clip-text text-transparent flex items-center gap-2">
                            <Trophy className="w-6 h-6 text-purple-600" />
                            API Arena
                        </h1>
                    </div>
                    
                    {/* Search Bar in Header */}
                    <form onSubmit={handleCompare} className="flex-1 max-w-2xl mx-4 flex gap-2">
                        <Input 
                            value={query}
                            onChange={(e) => setQuery(e.target.value)}
                            placeholder="Enter a query to compare providers..."
                            className="h-10"
                        />
                        <Button type="submit" disabled={loading} className="bg-purple-600 hover:bg-purple-700">
                            {loading ? <Loader2 className="w-4 h-4 animate-spin" /> : "Fight!"}
                        </Button>
                    </form>
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 max-w-7xl mx-auto w-full p-4 grid grid-cols-1 md:grid-cols-2 gap-4">
                
                {/* Left Column */}
                <ArenaColumn 
                    side="Left"
                    providers={providers}
                    selected={leftProvider}
                    onSelect={setLeftProvider}
                    result={leftResult}
                    opponentResult={rightResult}
                    loading={loading}
                />

                {/* Right Column */}
                <ArenaColumn 
                    side="Right"
                    providers={providers}
                    selected={rightProvider}
                    onSelect={setRightProvider}
                    result={rightResult}
                    opponentResult={leftResult}
                    loading={loading}
                />
            </div>
        </div>
    );
}

// Sub-component for each side of the arena
function ArenaColumn({ side, providers, selected, onSelect, result, opponentResult, loading }) {
    // Calculate comparison stats
    const isWinnerLatency = result?.metrics && opponentResult?.metrics && 
        (result.metrics.latency_ms < opponentResult.metrics.latency_ms);
    
    const isWinnerSize = result?.metrics && opponentResult?.metrics && 
        (result.metrics.size_bytes > opponentResult.metrics.size_bytes);

    return (
        <div className="flex flex-col gap-4 h-full">
            {/* Selector Card */}
            <Card className="p-4 border-t-4 border-t-transparent data-[side=Left]:border-t-blue-500 data-[side=Right]:border-t-orange-500" data-side={side}>
                <div className="flex justify-between items-center mb-2">
                    <span className="text-xs font-bold uppercase text-gray-400 tracking-wider">Contender {side}</span>
                </div>
                <select
                    className="w-full h-10 rounded-md border border-gray-300 px-3 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                    value={selected}
                    onChange={(e) => onSelect(e.target.value)}
                >
                    {providers.map((p) => (
                        <option key={p.name} value={p.name}>{p.name}</option>
                    ))}
                </select>

                {/* Metrics Display */}
                {result && !result.error && (
                    <div className="mt-4 space-y-3">
                        {/* Latency Bar */}
                        <div className="space-y-1">
                            <div className="flex justify-between text-xs">
                                <span className="flex items-center gap-1 text-gray-600">
                                    <Zap className="w-3 h-3" /> Latency
                                </span>
                                <span className={cn("font-mono font-bold", isWinnerLatency ? "text-green-600" : "text-gray-900")}>
                                    {result.metrics.latency_ms}ms
                                </span>
                            </div>
                            <div className="h-2 w-full bg-gray-100 rounded-full overflow-hidden">
                                <div 
                                    className={cn("h-full rounded-full transition-all duration-500", isWinnerLatency ? "bg-green-500" : "bg-gray-400")}
                                    style={{ width: '100%' }} // Simplified visualization
                                />
                            </div>
                        </div>

                        {/* Size Bar */}
                        <div className="space-y-1">
                            <div className="flex justify-between text-xs">
                                <span className="flex items-center gap-1 text-gray-600">
                                    <Database className="w-3 h-3" /> Payload
                                </span>
                                <span className="font-mono text-gray-900">
                                    {result.metrics.size_bytes} B
                                </span>
                            </div>
                        </div>
                    </div>
                )}
            </Card>

            {/* Results List Area */}
            <div className="flex-1 bg-gray-100/50 rounded-lg p-2 overflow-y-auto min-h-[500px] border border-dashed border-gray-200">
                {loading ? (
                    <div className="h-full flex flex-col items-center justify-center text-gray-400 gap-2">
                        <Loader2 className="w-8 h-8 animate-spin" />
                        <span className="text-sm">Fetching results...</span>
                    </div>
                ) : result?.error ? (
                    <div className="p-4 bg-red-50 text-red-600 rounded-md flex items-center gap-2 text-sm">
                        <AlertCircle className="w-4 h-4" /> {result.error}
                    </div>
                ) : result?.results ? (
                    <div className="space-y-3">
                         <div className="text-xs text-gray-400 text-center uppercase tracking-widest py-2">
                            {result.results.length} Results Found
                        </div>
                        {result.results.map((item, idx) => (
                            <ResultItem key={idx} item={item} compact={true} />
                        ))}
                    </div>
                ) : (
                    <div className="h-full flex items-center justify-center text-gray-400 text-sm">
                        Ready to compare
                    </div>
                )}
            </div>
        </div>
    );
}

export default ArenaPage;
