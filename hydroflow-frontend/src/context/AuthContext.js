import { createContext, useState, useContext, useEffect } from 'react';
import { authAPI } from '../services/api';

// Create Context - This is the state that holds the global auth state
const AuthContext = createContext(null);
// Auth Provider - Wraps the entire app so every component can access the auth state 
export const AuthProvider = ({ children }) => {
    const [user, setUser] = useState(null);
    const [token, setToken] = useState(null);
    const [loading, setLoading] = useState(true);

    // Check the Existing Session
    useEffect(() => {
        const storedToken = localStorage.getItem('hydroflow_token');
        const storedUser = localStorage.getItem('hydroflow_user');

        if (storedToken && storedUser) {
            setToken(storedToken);
            setUser(JSON.parse(storedUser));
        }

        // Done Checking - stop showing loading screen
        setLoading(false);
    }, []);

    // Login Function - Called when user submits login form
    const login = async (phone, password) => {
        try {
            const response = await authAPI.login({ phone, password });
            const { user, token } = response.data;

            // Save to state
            setUser(user);
            setToken(token);

            // Save to localStorage so session persists after page refresh
            localStorage.setItem('hydroflow_token', token);
            localStorage.setItem('hydroflow_user', JSON.stringify(user));

            return { success: true, user };

        } catch (error) {
            const message = error.response?.data?.message
                || 'Login failed. Please try again.';
            return { success: false, message };
        }
    };

    // Signup Function - Called when user submits signup form
    const signup = async ({ name, phone, email, password, role }) => {
        try {
            const response = await authAPI.register({ name, phone, email, password, role });
            const { user, token } = response.data;

            // Save to state
            setUser(user);
            setToken(token);

            // Save to localStorage
            localStorage.setItem('hydroflow_token', token);
            localStorage.setItem('hydroflow_user', JSON.stringify(user));

            return { success: true, user };
        } catch (error) {
            const message = error.response?.data?.message
                || 'Signup failed. Please try again.';
            return { success: false, message };
        }
    };

    // Logout function
    const logout = () => {
        setUser(null);
        setToken(null);
        localStorage.removeItem('hydroflow_token');
        localStorage.removeItem('hydroflow_user');
        window.location.href = '/login';
    };

    // Context Value 
    const value = {
        user,
        token, 
        loading,
        login,
        logout,
        signup,
        isAuthenticated: !!token,
        isAdmin: user?.role === 'admin',
        isDriver: user?.role === 'driver',
        isResident: user?.role === 'resident'
    };

    return (
        <AuthContext.Provider value={value}>
            {children}
        </AuthContext.Provider>
    );
};

// Custom Hook - Makes it easy to use auth in any component
export const useAuth = () => {
    const context = useContext(AuthContext);

    if (!context) {
        throw new Error('useAuth must be used within an AuthProvider');
    }

    return context;
};

export default AuthContext;