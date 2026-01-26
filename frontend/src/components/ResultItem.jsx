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

import { useState } from 'react';
import { ExternalLink, ChevronDown, ChevronUp, Clock } from 'lucide-react';
import { Card } from './Card';
import { cn } from '../lib/utils';

/**
 * Format page age as relative time if within 1 day, otherwise show date in YYYY-MM-DD format.
 * @param {string} dateStr - UTC date string from backend
 * @returns {string | null} Formatted time string, or null if parsing fails
 */
function formatPageAge(dateStr) {
    if (!dateStr) return null;
    try {
        const date = new Date(dateStr);
        if (isNaN(date.getTime())) return null;

        const now = new Date();
        const diffMs = now - date;
        const diffHours = diffMs / (1000 * 60 * 60);

        // Show relative time if within 1 day
        if (diffHours < 24) {
            if (diffHours < 1) {
                const diffMinutes = Math.floor(diffMs / (1000 * 60));
                if (diffMinutes < 1) {
                    return 'Just now';
                }
                return `${diffMinutes}m ago`;
            }
            const hours = Math.floor(diffHours);
            return `${hours}h ago`;
        }

        // Show date in YYYY-MM-DD format for older items
        const year = date.getUTCFullYear();
        const month = String(date.getUTCMonth() + 1).padStart(2, '0');
        const day = String(date.getUTCDate()).padStart(2, '0');
        return `${year}-${month}-${day}`;
    } catch {
        return null;
    }
}

export function ResultItem({ item, compact = false }) {
    const [expanded, setExpanded] = useState(false);
    const snippet = item.snippet || '';
    const LIMIT = compact ? 80 : 120;
    const shouldTruncate = snippet.length > LIMIT;

    const displaySnippet =
        shouldTruncate && !expanded
            ? snippet.substring(0, LIMIT) + '...'
            : snippet;

    const displayPageAge = formatPageAge(item.page_age);

    const toggleExpand = () => {
        setExpanded(!expanded);
    };

    return (
        <Card
            className={cn(
                'hover:shadow-md transition-shadow duration-200 border-gray-100',
                compact ? 'p-4' : 'p-5'
            )}
        >
            <div className="group">
                <a
                    href={item.url}
                    target="_blank"
                    rel="noopener noreferrer"
                    className="flex items-start justify-between gap-2"
                >
                    <h3 className={cn("font-medium text-blue-600 group-hover:underline break-words", compact ? "text-sm" : "text-base")}>
                        {item.title || 'Untitled'}
                    </h3>
                    <ExternalLink
                        className={cn(
                            'opacity-0 group-hover:opacity-50 transition-opacity mt-1 flex-shrink-0',
                            compact ? "w-3 h-3" : "w-4 h-4"
                        )}
                    />
                </a>
                <div className="text-xs mt-1 mb-2">
                    {displayPageAge ? (
                        <div className="flex items-center gap-1.5 text-green-700">
                            <span className="truncate">{displayPageAge}</span>
                            <span className="text-green-700">|</span>
                            {item.site_icon && (
                                <img src={item.site_icon} alt="" className="w-4 h-4 flex-shrink-0" />
                            )}
                            <span className="truncate max-w-[200px]">{item.site_name || item.url}</span>
                        </div>
                    ) : (
                        <span className="truncate max-w-full text-green-700 inline-flex items-center gap-1.5">
                            {item.site_icon && (
                                <img src={item.site_icon} alt="" className="w-4 h-4 flex-shrink-0" />
                            )}
                            {item.site_name || item.url}
                        </span>
                    )}
                </div>

                <div className={cn("text-gray-700 leading-relaxed", compact ? "text-xs" : "text-sm")}>
                    {displaySnippet}
                    {shouldTruncate && (
                        <button
                            onClick={toggleExpand}
                            className={cn(
                                'ml-2 text-blue-600 hover:text-blue-800 font-medium inline-flex items-center gap-0.5'
                            )}
                        >
                            {expanded ? (
                                <>
                                    Collapse <ChevronUp className="w-3 h-3" />
                                </>
                            ) : (
                                <>
                                    Expand <ChevronDown className="w-3 h-3" />
                                </>
                            )}
                        </button>
                    )}
                </div>
            </div>
        </Card>
    );
}
