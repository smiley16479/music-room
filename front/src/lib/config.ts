// Application configuration
export const config = {
    // Application name
    appName: 'Music Room',
    
    // API endpoint
    apiUrl: 'http://localhost:3000',

    
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
        eventPrivacy: 'public', // 'public' or 'private'
        playlistPrivacy: 'public', // 'public' or 'private'
    }
};
