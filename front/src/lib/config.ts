// Application configuration
export const config = {
    // Application name
    appName: 'Music Room',
    
    // API endpoint - use localhost for browser requests, docker service name for server requests
    apiUrl: typeof window !== 'undefined' 
        ? (import.meta.env.VITE_API_URL_BROWSER || 'http://localhost:3000')
        : (import.meta.env.VITE_API_URL || 'http://back:3000'),
    
    features: {
        trackVoting: true,
        playlistEditor: true,
        controlDelegation: true,
        
        socialAuth: {
            google: true,
            facebook: true
        }
    },
    
    defaults: {
        eventPrivacy: 'public',
        playlistPrivacy: 'public',
    }
};
