// Weather Globe Application - Enhanced Version
// Note: In production, API keys should be handled server-side

// Configuration - In production, this should come from environment variables
const CONFIG = {
    API_KEY: '6e96f2d6545ae9c1f6c3fb8856b238a6', // OpenWeatherMap API key
    BASE_URL: 'https://api.openweathermap.org/data/2.5/weather',
    ICON_BASE_URL: 'https://openweathermap.org/img/wn/', // Base URL for weather icons
    DEFAULT_UNITS: 'imperial', // fahrenheit, for celsius use 'metric'
    REQUEST_TIMEOUT: 10000, // 10 seconds
    GEOLOCATION_TIMEOUT: 10000,
    GEOLOCATION_MAX_AGE: 300000 // 5 minutes
};

// Application state
const AppState = {  
    isLoading: false,
    lastSearchCity: '',
    requestCount: 0,
    errors: []
};

// DOM Elements Cache
const Elements = {
    cityInput: null, // 
    spinner: null,
    loading: null,
    errorMessage: null,
    weatherContainer: null,
    locationName: null,
    weatherIcon: null,
    temperature: null,
    weatherDescription: null,
    feelsLike: null,
    humidity: null,
    windSpeed: null,
    pressure: null
};

// Initialize application when DOM is ready
$(document).ready(function () {
    initializeApp();
    setupEventListeners();
    getCurrentLocationWeather();
});

// Initialize application
function initializeApp() {
    // Cache DOM elements
    Elements.cityInput = $('#cityInput');
    Elements.spinner = $('#spinner');
    Elements.loading = $('#loading');
    Elements.errorMessage = $('#errorMessage');
    Elements.weatherContainer = $('#weatherContainer');
    Elements.locationName = $('#locationName');
    Elements.weatherIcon = $('#weatherIcon');
    Elements.temperature = $('#temperature');
    Elements.weatherDescription = $('#weatherDescription');
    Elements.feelsLike = $('#feelsLike');
    Elements.humidity = $('#humidity');
    Elements.windSpeed = $('#windSpeed');
    Elements.pressure = $('#pressure');
    
    console.log('Weather Globe App initialized successfully');
}

// Setup event listeners
function setupEventListeners() {
    // Enter key press in search input
    Elements.cityInput.on('keypress', function (e) {
        if (e.which === 13) {
            e.preventDefault();
            searchWeather();
        }
    });
    
    // Input validation and sanitization
    Elements.cityInput.on('input', function () {
        const value = $(this).val();
        // Remove any potentially harmful characters
        const sanitized = value.replace(/[<>\"'&]/g, '');
        if (value !== sanitized) {
            $(this).val(sanitized);
        }
    });
    
    // Clear error message when user starts typing
    Elements.cityInput.on('focus', function () {
        hideError();
    });
}

// Show loading state
function showLoading() {
    AppState.isLoading = true;
    Elements.spinner.addClass('show');
    Elements.loading.addClass('show');
    Elements.errorMessage.removeClass('show');
    Elements.weatherContainer.removeClass('show');
}

// Hide loading state
function hideLoading() {
    AppState.isLoading = false;
    Elements.spinner.removeClass('show');
    Elements.loading.removeClass('show');
}

// Show error message
function showError(message) {
    hideLoading();
    AppState.errors.push({
        message: message,
        timestamp: new Date().toISOString()
    });
    
    Elements.errorMessage.text(message).addClass('show');
    Elements.weatherContainer.removeClass('show');
    
    console.error('Weather App Error:', message);
}

// Hide error message
function hideError() {
    Elements.errorMessage.removeClass('show');
}

// Display weather data
function displayWeather(data) {
    try {
        hideLoading();
        hideError();

        // Validate required data
        if (!data || !data.weather || !data.weather[0] || !data.main) {
            throw new Error('Invalid weather data received');
        }

        const iconUrl = `${CONFIG.ICON_BASE_URL}${data.weather[0].icon}@2x.png`;
        const temp = Math.round(data.main.temp);
        const feelsLike = Math.round(data.main.feels_like);
        const description = data.weather[0].description;
        
        // Update DOM elements with data
        Elements.locationName.text(`${data.name}, ${data.sys.country}`);
        Elements.weatherIcon.attr('src', iconUrl).attr('alt', description);
        Elements.temperature.text(`${temp}°F`);
        Elements.weatherDescription.text(description);
        Elements.feelsLike.text(`${feelsLike}°F`);
        Elements.humidity.text(`${data.main.humidity}%`);
        Elements.windSpeed.text(`${Math.round(data.wind?.speed || 0)} mph`);
        Elements.pressure.text(`${data.main.pressure} hPa`);

        // Show weather container with animation delay
        setTimeout(() => {
            Elements.weatherContainer.addClass('show');
        }, 100);
        
        console.log('Weather data displayed successfully for:', data.name);
        
    } catch (error) {
        console.error('Error displaying weather data:', error);
        showError('Error displaying weather information. Please try again.');
    }
}

// Search weather by city name
function searchWeather() {
    const city = Elements.cityInput.val().trim();

    // Input validation
    if (!city) {
        showError('Please enter a city name');
        return;
    }
    
    if (city.length < 2) {
        showError('City name must be at least 2 characters long');
        return;
    }
    
    if (city.length > 100) {
        showError('City name is too long');
        return;
    }

    // Prevent duplicate requests
    if (city === AppState.lastSearchCity && AppState.isLoading) {
        return;
    }
    
    AppState.lastSearchCity = city;
    AppState.requestCount++;
    
    showLoading();

    // Build API URL with proper encoding
    const url = buildWeatherUrl('q', encodeURIComponent(city));
    
    // Make API request with timeout and error handling
    makeWeatherRequest(url, 'city search');
}

// Get weather for current location
function getCurrentLocationWeather() {
    if (!navigator.geolocation) {
        showError('Geolocation is not supported by this browser.');
        return;
    }

    showLoading();

    const options = {
        timeout: CONFIG.GEOLOCATION_TIMEOUT,
        enableHighAccuracy: true,
        maximumAge: CONFIG.GEOLOCATION_MAX_AGE
    };

    navigator.geolocation.getCurrentPosition(
        function (position) {
            const lat = position.coords.latitude;
            const lon = position.coords.longitude;
            
            console.log('Location obtained:', { lat, lon });
            
            const url = buildWeatherUrl('lat', lat, 'lon', lon);
            makeWeatherRequest(url, 'geolocation');
        },
        function (error) {
            console.error('Geolocation error:', error);
            hideLoading();
            
            const errorMessages = {
                [error.PERMISSION_DENIED]: 'Location access denied. Please search for a city manually.',
                [error.POSITION_UNAVAILABLE]: 'Location information unavailable. Please search for a city manually.',
                [error.TIMEOUT]: 'Location request timed out. Please search for a city manually.',
                'default': 'An unknown location error occurred. Please search for a city manually.'
            };
            
            const message = errorMessages[error.code] || errorMessages.default;
            showError(message);
        },
        options
    );
}

// Build weather API URL
function buildWeatherUrl(...params) {
    const url = new URL(CONFIG.BASE_URL);
    
    // Add parameters in pairs
    for (let i = 0; i < params.length; i += 2) {
        if (i + 1 < params.length) {
            url.searchParams.append(params[i], params[i + 1]);
        }
    }
    
    // Add common parameters
    url.searchParams.append('units', CONFIG.DEFAULT_UNITS);
    url.searchParams.append('appid', CONFIG.API_KEY);
    
    return url.toString();
}

// Make weather API request
function makeWeatherRequest(url, requestType = 'unknown') {
    const requestStartTime = Date.now();
    
    // Create a timeout promise
    const timeoutPromise = new Promise((_, reject) => {
        setTimeout(() => reject(new Error('Request timeout')), CONFIG.REQUEST_TIMEOUT);
    });
    
    // Create the actual request promise
    const requestPromise = $.getJSON(url);
    
    // Race between timeout and actual request
    Promise.race([requestPromise, timeoutPromise])
        .then(data => {
            const requestTime = Date.now() - requestStartTime;
            console.log(`Weather data received (${requestType}):`, {
                city: data.name,
                country: data.sys.country,
                requestTime: `${requestTime}ms`,
                requestCount: AppState.requestCount
            });
            
            displayWeather(data);
        })
        .catch(error => {
            const requestTime = Date.now() - requestStartTime;
            console.error(`Error fetching weather data (${requestType}):`, {
                error: error,
                requestTime: `${requestTime}ms`,
                url: url.replace(CONFIG.API_KEY, 'API_KEY_HIDDEN')
            });
            
            handleApiError(error);
        });
}

// Handle API errors
function handleApiError(error) {
    let errorMessage = 'Unable to fetch weather data. Please try again later.';
    
    if (error.message === 'Request timeout') {
        errorMessage = 'Request timed out. Please check your internet connection and try again.';
    } else if (error.responseJSON) {
        // Handle OpenWeatherMap API specific errors
        switch (error.status) {
            case 404:
                errorMessage = 'City not found. Please check the spelling and try again.';
                break;
            case 401:
                errorMessage = 'API key error. Please check your API configuration.';
                break;
            case 429:
                errorMessage = 'Too many requests. Please wait a moment and try again.';
                break;
            case 500:
            case 502:
            case 503:
                errorMessage = 'Weather service is temporarily unavailable. Please try again later.';
                break;
        }
    } else if (!navigator.onLine) {
        errorMessage = 'No internet connection. Please check your network and try again.';
    }
    
    showError(errorMessage);
}

// Utility function to get user's preferred units
function getUserPreferredUnits() {
    // This could be enhanced to remember user preferences
    return localStorage.getItem('preferredUnits') || CONFIG.DEFAULT_UNITS;
}

// Utility function to format temperature based on units
function formatTemperature(temp, units = CONFIG.DEFAULT_UNITS) {
    const rounded = Math.round(temp);
    const symbol = units === 'metric' ? '°C' : '°F';
    return `${rounded}${symbol}`;
}

// Utility function to convert wind speed
function formatWindSpeed(speed, units = CONFIG.DEFAULT_UNITS) {
    const rounded = Math.round(speed);
    const unit = units === 'metric' ? 'km/h' : 'mph';
    return `${rounded} ${unit}`;
}

// Performance monitoring
function logPerformanceMetrics() {
    if (window.performance && window.performance.getEntriesByType) {
        const entries = window.performance.getEntriesByType('navigation');
        if (entries.length > 0) {
            console.log('Page load performance:', {
                loadTime: `${Math.round(entries[0].loadEventEnd - entries[0].fetchStart)}ms`,
                domReady: `${Math.round(entries[0].domContentLoadedEventEnd - entries[0].fetchStart)}ms`
            });
        }
    }
}

// Initialize performance monitoring
$(window).on('load', function() {
    setTimeout(logPerformanceMetrics, 1000);
});

// Global error handler for uncaught errors
window.addEventListener('error', function(event) {
    console.error('Global error caught:', event.error);
    if (!AppState.isLoading) {
        // Only show error if we're not already in an error state
        showError('An unexpected error occurred. Please refresh the page.');
    }
});

// Export functions for testing (if in development environment)
if (typeof module !== 'undefined' && module.exports) {
    module.exports = {
        searchWeather,
        getCurrentLocationWeather,
        buildWeatherUrl,
        formatTemperature,
        formatWindSpeed
    };
}