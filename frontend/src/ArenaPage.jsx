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
import { useNavigate, useSearchParams } from 'react-router-dom';
import {
    ArrowLeft,
    Search,
    Zap,
    Clock,
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
import { getPreviousEngine, getAlternativeEngine } from './utils/engineHistory';

function ArenaPage() {
    const navigate = useNavigate();
    const [searchParams] = useSearchParams();
    const [providers, setProviders] = useState([]);

    // Arena State
    const [leftProvider, setLeftProvider] = useState('');
    const [rightProvider, setRightProvider] = useState('');
    const [query, setQuery] = useState('');
    const [loading, setLoading] = useState(false);

    // Status messages for each side
    const [leftStatus, setLeftStatus] = useState('');
    const [rightStatus, setRightStatus] = useState('');

    // Results State
    const [leftResult, setLeftResult] = useState(null);
    const [rightResult, setRightResult] = useState(null);

    // Initial Load
    useEffect(() => {
        fetch('/api/providers')
            .then((res) => res.json())
            .then((data) => {
                setProviders(data);

                // Get current engine from URL parameter
                const currentEngine = searchParams.get('current');

                if (currentEngine && data.find(p => p.name === currentEngine)) {
                    // Use current engine as left provider
                    setLeftProvider(currentEngine);

                    // Try to get previous engine from history
                    const previousEngine = getPreviousEngine(currentEngine);

                    if (previousEngine && data.find(p => p.name === previousEngine)) {
                        // Use previous engine as right provider
                        setRightProvider(previousEngine);
                    } else {
                        // Use alternative engine from providers list
                        const alternativeEngine = getAlternativeEngine(currentEngine, data);
                        setRightProvider(alternativeEngine || currentEngine);
                    }
                } else {
                    // Fallback to original logic
                    if (data.length >= 2) {
                        setLeftProvider(data[0].name);
                        setRightProvider(data[1].name);
                    } else if (data.length === 1) {
                        setLeftProvider(data[0].name);
                        setRightProvider(data[0].name);
                    }
                }
            })
            .catch(console.error);
    }, [searchParams]);

    const performSearch = async (provider, queryText, setStatusCallback) => {
        try {
            const start = performance.now();
            const res = await fetch('/api/search', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query: queryText, provider: provider, stream: true }),
            });

            // Check if response is SSE
            const contentType = res.headers.get('content-type');
            if (contentType && contentType.includes('text/event-stream')) {
                // Handle SSE stream
                const reader = res.body.getReader();
                const decoder = new TextDecoder();
                let buffer = '';
                let finalResult = null;

                while (true) {
                    const { done, value } = await reader.read();
                    if (done) break;

                    buffer += decoder.decode(value, { stream: true });
                    const lines = buffer.split('\n\n');
                    buffer = lines.pop() || '';

                    for (const line of lines) {
                        if (line.startsWith('data: ')) {
                            const data = JSON.parse(line.slice(6));

                            if (data.type === 'status') {
                                setStatusCallback(data.message);
                            } else if (data.type === 'result') {
                                const end = performance.now();
                                const clientLatency = Math.round(end - start);

                                if (data.data.error) {
                                    finalResult = { error: data.data.error };
                                } else {
                                    finalResult = {
                                        results: data.data.results || [],
                                        metrics: {
                                            latency_ms: data.data.metrics?.latency_ms || clientLatency,
                                            server_latency_ms: data.data.metrics?.server_latency_ms || null,
                                            size_bytes: data.data.metrics?.size_bytes || 0
                                        }
                                    };
                                }
                            }
                        }
                    }
                }

                return finalResult || { error: 'No result received' };
            } else {
                // Fallback to non-streaming
                const data = await res.json();
                const end = performance.now();
                const clientLatency = Math.round(end - start);

                if (data.error) return { error: data.error };

                return {
                    results: data.results || [],
                    metrics: {
                        latency_ms: data.metrics?.latency_ms || clientLatency,
                        server_latency_ms: data.metrics?.server_latency_ms || null,
                        size_bytes: data.metrics?.size_bytes || 0
                    }
                };
            }
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
        setLeftStatus('');
        setRightStatus('');

        // Run in parallel
        const [res1, res2] = await Promise.all([
            performSearch(leftProvider, query, setLeftStatus),
            performSearch(rightProvider, query, setRightStatus)
        ]);

        setLeftResult(res1);
        setRightResult(res2);
        setLoading(false);
        setLeftStatus('');
        setRightStatus('');
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-50 to-indigo-50 flex flex-col">
            {/* Header */}
            <div className="bg-white/80 backdrop-blur-md border-b sticky top-0 z-50 shadow-md">
                <div className="max-w-7xl mx-auto px-3 sm:px-4 h-14 sm:h-16 flex items-center justify-between gap-2 sm:gap-4">
                    <div className="flex items-center gap-2 sm:gap-4 flex-shrink-0">
                        <Button
                            variant="ghost"
                            size="icon"
                            onClick={() => navigate(`/?provider=${leftProvider}`)}
                            className="h-8 w-8 sm:h-10 sm:w-10"
                        >
                            <ArrowLeft className="w-4 h-4 sm:w-5 sm:h-5 text-gray-600" />
                        </Button>
                        <h1 className="text-sm sm:text-lg md:text-xl font-bold bg-gradient-to-r from-purple-600 via-pink-600 to-blue-600 bg-clip-text text-transparent flex items-center gap-1 sm:gap-2 drop-shadow-sm">
                            <Trophy className="w-4 h-4 sm:w-5 sm:h-5 md:w-6 md:h-6 text-purple-600 flex-shrink-0" />
                            <span className="hidden sm:inline">SearchAPIWebUI Arena</span>
                            <span className="sm:hidden">Arena</span>
                        </h1>
                    </div>

                    {/* Search Bar in Header */}
                    <form onSubmit={handleCompare} className="flex-1 max-w-2xl flex gap-2">
                        <Input
                            value={query}
                            onChange={(e) => setQuery(e.target.value)}
                            placeholder="Compare providers..."
                            className="h-8 sm:h-9 md:h-10 text-sm"
                        />
                        <Button
                            type="submit"
                            disabled={loading}
                            className="bg-gradient-to-r from-purple-600 to-pink-600 hover:from-purple-700 hover:to-pink-700 h-8 sm:h-9 md:h-10 px-3 sm:px-4 text-sm whitespace-nowrap shadow-md hover:shadow-lg transition-all duration-200"
                        >
                            {loading ? <Loader2 className="w-3 h-3 sm:w-4 sm:h-4 animate-spin" /> : <span className="hidden sm:inline">Fight!</span>}
                            {loading ? '' : <span className="sm:hidden">Go</span>}
                        </Button>
                    </form>
                </div>
            </div>

            {/* Main Content */}
            <div className="flex-1 max-w-7xl mx-auto w-full p-2 sm:p-3 md:p-4 grid grid-cols-1 lg:grid-cols-2 gap-3 sm:gap-4">

                {/* Left Column */}
                <ArenaColumn
                    side="Left"
                    providers={providers}
                    selected={leftProvider}
                    onSelect={setLeftProvider}
                    result={leftResult}
                    opponentResult={rightResult}
                    loading={loading}
                    statusMessage={leftStatus}
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
                    statusMessage={rightStatus}
                />
            </div>
        </div>
    );
}

// Sub-component for each side of the arena
function ArenaColumn({ side, providers, selected, onSelect, result, opponentResult, loading, statusMessage }) {
    // Calculate comparison stats
    const isWinnerLatency = result?.metrics && opponentResult?.metrics &&
        (result.metrics.latency_ms < opponentResult.metrics.latency_ms);

    const isWinnerSize = result?.metrics && opponentResult?.metrics &&
        (result.metrics.size_bytes > opponentResult.metrics.size_bytes);

    return (
        <div className="flex flex-col gap-3 sm:gap-4 h-full">
            {/* Selector Card */}
            <Card className={cn(
                "p-3 sm:p-4 border-t-8 shadow-lg hover:shadow-xl transition-all duration-300",
                side === "Left"
                    ? "border-t-blue-500 bg-gradient-to-br from-blue-50/50 to-white"
                    : "border-t-orange-500 bg-gradient-to-br from-orange-50/50 to-white"
            )} data-side={side}>
                <div className="mb-2 sm:mb-3">
                    <div className="text-xs sm:text-sm font-semibold text-gray-500 mb-2">{side} Provider</div>
                    <select
                        className="w-full h-9 sm:h-10 rounded-md border border-gray-300 px-2 sm:px-3 text-sm focus:outline-none focus:ring-2 focus:ring-purple-500"
                        value={selected}
                        onChange={(e) => onSelect(e.target.value)}
                    >
                        {providers.map((p) => (
                            <option key={p.name} value={p.name}>{p.name}</option>
                        ))}
                    </select>
                </div>

                {/* Metrics Display */}
                {result && !result.error && (
                    <div className="mt-3 sm:mt-4 space-y-2 sm:space-y-3">
                        {/* Client Latency Bar */}
                        <div className="space-y-1">
                            <div className="flex justify-between text-xs">
                                <span className="flex items-center gap-1 text-gray-600">
                                    <Clock className="w-3 h-3" />
                                    <span className="hidden sm:inline">Client Latency</span>
                                    <span className="sm:hidden">Latency</span>
                                </span>
                                <span className={cn("font-mono font-bold text-xs sm:text-sm", isWinnerLatency ? "text-emerald-600 drop-shadow-sm" : "text-gray-900")}>
                                    {result.metrics.latency_ms}ms
                                </span>
                            </div>
                            <div className="h-2 w-full bg-gray-100 rounded-full overflow-hidden shadow-inner">
                                <div
                                    className={cn("h-full rounded-full transition-all duration-500 shadow-sm", isWinnerLatency ? "bg-gradient-to-r from-emerald-500 to-emerald-400" : "bg-gray-400")}
                                    style={{ width: '100%' }}
                                />
                            </div>
                        </div>

                        {/* Server Latency (if available) */}
                        {result.metrics.server_latency_ms !== null && (
                            <div className="space-y-1">
                                <div className="flex justify-between text-xs">
                                    <span className="flex items-center gap-1 text-gray-600">
                                        <Zap className="w-3 h-3" />
                                        <span className="hidden sm:inline">Server Latency</span>
                                        <span className="sm:hidden">Server</span>
                                    </span>
                                    <span className="font-mono font-bold text-blue-600 text-xs sm:text-sm">
                                        {result.metrics.server_latency_ms}ms
                                    </span>
                                </div>
                            </div>
                        )}

                        {/* Size Bar */}
                        <div className="space-y-1">
                            <div className="flex justify-between text-xs">
                                <span className="flex items-center gap-1 text-gray-600">
                                    <Database className="w-3 h-3" />
                                    <span className="hidden sm:inline">Response Size</span>
                                    <span className="sm:hidden">Size</span>
                                </span>
                                <span className="font-mono text-gray-900 text-xs sm:text-sm">
                                    {result.metrics.size_bytes} B
                                </span>
                            </div>
                        </div>
                    </div>
                )}
            </Card>

            {/* Results List Area */}
            <div className="flex-1 bg-gray-100/50 rounded-lg p-2 overflow-y-auto min-h-[300px] sm:min-h-[400px] lg:min-h-[500px] border border-dashed border-gray-200">
                {loading ? (
                    <div className="h-full flex flex-col items-center justify-center text-gray-400 gap-2">
                        <Loader2 className="w-6 h-6 sm:w-8 sm:h-8 animate-spin" />
                        <span className="text-xs sm:text-sm text-center px-2">{statusMessage || 'Fetching results...'}</span>
                    </div>
                ) : result?.error ? (
                    <div className="p-3 sm:p-4 bg-red-50 text-red-600 rounded-md flex items-center gap-2 text-xs sm:text-sm">
                        <AlertCircle className="w-4 h-4 flex-shrink-0" /> <span>{result.error}</span>
                    </div>
                ) : result?.results ? (
                    <div className="space-y-2 sm:space-y-3">
                         <div className="text-xs text-gray-400 text-center uppercase tracking-widest py-2">
                            {result.results.length} Results Found
                        </div>
                        {result.results.map((item, idx) => (
                            <ResultItem key={idx} item={item} compact={true} watermark={selected} />
                        ))}
                    </div>
                ) : (
                    <div className="h-full flex items-center justify-center text-gray-400 text-xs sm:text-sm">
                        Ready to compare
                    </div>
                )}
            </div>
        </div>
    );
}

export default ArenaPage;
