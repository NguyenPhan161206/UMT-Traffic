import { useState, useEffect } from 'react';
import { supabase } from '../lib/supabase';

interface UserProfile {
  id: string;
  email: string;
  display_name?: string;
  school_id?: string;
  grade?: string;
  is_registered: boolean;
  role?: string;
}

interface UseUserReturn {
  user: UserProfile | null;
  loading: boolean;
  logout: () => Promise<void>;
}

export function useUser(): UseUserReturn {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const loadUser = async () => {
      try {
        const {
          data: { user: authUser },
        } = await supabase.auth.getUser();

        if (!authUser) {
          setUser(null);
          setLoading(false);
          return;
        }

        const { data: profile } = await supabase
          .from('profiles')
          .select('*')
          .eq('id', authUser.id)
          .single();

        const { data: adminRole } = await supabase
          .from('roles')
          .select('id')
          .eq('name', 'admin')
          .maybeSingle();

        let roleName = 'student';
        if (adminRole?.id) {
          const { data: userAdminRole } = await supabase
            .from('user_roles')
            .select('role_id')
            .eq('user_id', authUser.id)
            .eq('role_id', adminRole.id)
            .maybeSingle();

          if (userAdminRole) {
            roleName = 'admin';
          }
        }

        setUser({
          id: authUser.id,
          email: authUser.email || '',
          display_name: profile?.display_name,
          school_id: profile?.school_id,
          grade: profile?.grade,
          is_registered: profile?.is_registered || false,
          role: roleName,
        });
      } catch (e: unknown) {
        if (e instanceof Error) console.error('Error loading user:', e.message);
        setUser(null);
      } finally {
        setLoading(false);
      }
    };

    loadUser();

    const { data } = supabase.auth.onAuthStateChange(() => {
      loadUser();
    });

    return () => {
      data?.subscription?.unsubscribe();
    };
  }, []);

  async function logout() {
    await supabase.auth.signOut();
  }

  return { user, loading, logout };
}
