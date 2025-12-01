import { useState, useEffect } from 'react'

function AnalyticsPage() {
  const [shortCode, setShortCode] = useState('')
  const [stats, setStats] = useState(null)
  const [platformStats, setPlatformStats] = useState(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')
  const [activeTab, setActiveTab] = useState('url') // 'url' or 'platform'

  const fetchUrlStats = async () => {
    if (!shortCode.trim()) {
      setError('Please enter a short code')
      return
    }

    setError('')
    setLoading(true)

    try {
      const response = await fetch(`http://localhost:8080/api/v1/stats/url/${shortCode}`)
      
      if (!response.ok) {
        if (response.status === 404) {
          throw new Error('Short URL not found or has no statistics yet')
        }
        throw new Error('Failed to fetch statistics')
      }

      const data = await response.json()
      setStats(data)
    } catch (err) {
      setError(err.message || 'An error occurred. Please try again.')
      setStats(null)
    } finally {
      setLoading(false)
    }
  }

  const fetchPlatformStats = async () => {
    setError('')
    setLoading(true)

    try {
      const response = await fetch('http://localhost:8080/api/v1/stats/platform')
      
      if (!response.ok) {
        throw new Error('Failed to fetch platform statistics')
      }

      const data = await response.json()
      setPlatformStats(data)
    } catch (err) {
      setError(err.message || 'An error occurred. Please try again.')
      setPlatformStats(null)
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    if (activeTab === 'platform') {
      fetchPlatformStats()
    }
  }, [activeTab])

  const handleSubmit = (e) => {
    e.preventDefault()
    fetchUrlStats()
  }

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 py-8 px-4">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <h1 className="text-5xl font-bold text-gray-900 mb-2">
            Analytics Dashboard
          </h1>
          <p className="text-gray-600 text-lg">
            Track your URL performance and platform statistics
          </p>
        </div>

        {/* Tabs */}
        <div className="flex gap-4 mb-6 justify-center">
          <button
            onClick={() => setActiveTab('url')}
            className={`px-6 py-3 rounded-lg font-semibold transition-all ${
              activeTab === 'url'
                ? 'bg-indigo-600 text-white shadow-lg'
                : 'bg-white text-gray-700 hover:bg-gray-50'
            }`}
          >
            URL Statistics
          </button>
          <button
            onClick={() => setActiveTab('platform')}
            className={`px-6 py-3 rounded-lg font-semibold transition-all ${
              activeTab === 'platform'
                ? 'bg-indigo-600 text-white shadow-lg'
                : 'bg-white text-gray-700 hover:bg-gray-50'
            }`}
          >
            Platform Statistics
          </button>
        </div>

        {/* URL Statistics Tab */}
        {activeTab === 'url' && (
          <div className="bg-white rounded-2xl shadow-xl p-8">
            <form onSubmit={handleSubmit} className="mb-6">
              <div className="flex gap-2">
                <input
                  type="text"
                  value={shortCode}
                  onChange={(e) => setShortCode(e.target.value)}
                  placeholder="Enter short code (e.g., t6fXRb)"
                  className="flex-1 px-4 py-3 border border-gray-300 rounded-lg focus:ring-2 focus:ring-indigo-500 focus:border-transparent outline-none"
                />
                <button
                  type="submit"
                  disabled={loading}
                  className="px-6 py-3 bg-indigo-600 text-white rounded-lg font-semibold hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed transition-all"
                >
                  {loading ? 'Loading...' : 'Get Stats'}
                </button>
              </div>
            </form>

            {error && (
              <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                <p className="text-red-800 text-sm">{error}</p>
              </div>
            )}

            {stats && (
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
                  <div className="bg-blue-50 p-6 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Total Clicks</p>
                    <p className="text-3xl font-bold text-blue-600">{stats.totalClicks || 0}</p>
                  </div>
                  <div className="bg-green-50 p-6 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Clicks Today</p>
                    <p className="text-3xl font-bold text-green-600">{stats.clicksToday || 0}</p>
                  </div>
                  <div className="bg-purple-50 p-6 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Clicks This Week</p>
                    <p className="text-3xl font-bold text-purple-600">{stats.clicksThisWeek || 0}</p>
                  </div>
                  <div className="bg-orange-50 p-6 rounded-lg">
                    <p className="text-sm text-gray-600 mb-1">Clicks This Month</p>
                    <p className="text-3xl font-bold text-orange-600">{stats.clicksThisMonth || 0}</p>
                  </div>
                </div>

                {stats.topCountries && stats.topCountries.length > 0 && (
                  <div className="bg-gray-50 p-6 rounded-lg">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Top Countries</h3>
                    <div className="space-y-2">
                      {stats.topCountries.map((country, index) => (
                        <div key={index} className="flex justify-between items-center">
                          <span className="text-gray-700">{country.country || 'Unknown'}</span>
                          <span className="font-semibold text-indigo-600">{country.clicks} clicks</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {stats.clickTimeline && stats.clickTimeline.length > 0 && (
                  <div className="bg-gray-50 p-6 rounded-lg">
                    <h3 className="text-lg font-semibold text-gray-900 mb-4">Click Timeline</h3>
                    <div className="space-y-2">
                      {stats.clickTimeline.map((timeline, index) => (
                        <div key={index} className="flex justify-between items-center">
                          <span className="text-gray-700">{timeline.date}</span>
                          <span className="font-semibold text-indigo-600">{timeline.clicks} clicks</span>
                        </div>
                      ))}
                    </div>
                  </div>
                )}

                {stats.firstClickAt && (
                  <div className="text-sm text-gray-500">
                    <p>First click: {new Date(stats.firstClickAt).toLocaleString()}</p>
                    {stats.lastClickAt && (
                      <p>Last click: {new Date(stats.lastClickAt).toLocaleString()}</p>
                    )}
                  </div>
                )}
              </div>
            )}
          </div>
        )}

        {/* Platform Statistics Tab */}
        {activeTab === 'platform' && (
          <div className="bg-white rounded-2xl shadow-xl p-8">
            {loading && !platformStats && (
              <div className="text-center py-8">
                <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-indigo-600 mx-auto"></div>
                <p className="mt-4 text-gray-600">Loading platform statistics...</p>
              </div>
            )}

            {error && (
              <div className="mb-6 p-4 bg-red-50 border border-red-200 rounded-lg">
                <p className="text-red-800 text-sm">{error}</p>
              </div>
            )}

            {platformStats && (
              <div className="space-y-6">
                <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
                  <div className="bg-blue-50 p-6 rounded-lg text-center">
                    <p className="text-sm text-gray-600 mb-2">Active URLs</p>
                    <p className="text-4xl font-bold text-blue-600">{platformStats.activeUrls || platformStats.totalUrls || 0}</p>
                  </div>
                  <div className="bg-green-50 p-6 rounded-lg text-center">
                    <p className="text-sm text-gray-600 mb-2">Total Clicks</p>
                    <p className="text-4xl font-bold text-green-600">{platformStats.totalClicks || 0}</p>
                  </div>
                  <div className="bg-purple-50 p-6 rounded-lg text-center">
                    <p className="text-sm text-gray-600 mb-2">Clicks Today</p>
                    <p className="text-4xl font-bold text-purple-600">{platformStats.clicksToday || 0}</p>
                  </div>
                </div>

                {platformStats.lastUpdated && (
                  <div className="text-sm text-gray-500 text-center">
                    Last updated: {new Date(platformStats.lastUpdated).toLocaleString()}
                  </div>
                )}
              </div>
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default AnalyticsPage

