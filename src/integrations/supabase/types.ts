export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.5"
  }
  public: {
    Tables: {
      admin_audit_logs: {
        Row: {
          action_type: string
          admin_id: string | null
          created_at: string
          id: string
          new_data: Json | null
          old_data: Json | null
          target_id: string
          target_table: string
        }
        Insert: {
          action_type: string
          admin_id?: string | null
          created_at?: string
          id?: string
          new_data?: Json | null
          old_data?: Json | null
          target_id: string
          target_table: string
        }
        Update: {
          action_type?: string
          admin_id?: string | null
          created_at?: string
          id?: string
          new_data?: Json | null
          old_data?: Json | null
          target_id?: string
          target_table?: string
        }
        Relationships: []
      }
      analytics_events: {
        Row: {
          created_at: string | null
          event_name: string
          id: string
          metadata: Json | null
          user_id: string | null
        }
        Insert: {
          created_at?: string | null
          event_name: string
          id?: string
          metadata?: Json | null
          user_id?: string | null
        }
        Update: {
          created_at?: string | null
          event_name?: string
          id?: string
          metadata?: Json | null
          user_id?: string | null
        }
        Relationships: []
      }
      app_settings: {
        Row: {
          description: string | null
          id: string
          key: string
          updated_at: string | null
          value: Json
        }
        Insert: {
          description?: string | null
          id?: string
          key: string
          updated_at?: string | null
          value: Json
        }
        Update: {
          description?: string | null
          id?: string
          key?: string
          updated_at?: string | null
          value?: Json
        }
        Relationships: []
      }
      fraud_flags: {
        Row: {
          created_at: string | null
          details: Json | null
          id: string
          severity: string | null
          status: string | null
          type: string
          user_id: string
        }
        Insert: {
          created_at?: string | null
          details?: Json | null
          id?: string
          severity?: string | null
          status?: string | null
          type: string
          user_id: string
        }
        Update: {
          created_at?: string | null
          details?: Json | null
          id?: string
          severity?: string | null
          status?: string | null
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      notifications: {
        Row: {
          created_at: string
          id: string
          is_read: boolean
          message: string
          metadata: Json | null
          title: string
          transaction_id: string | null
          type: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          is_read?: boolean
          message: string
          metadata?: Json | null
          title: string
          transaction_id?: string | null
          type: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          is_read?: boolean
          message?: string
          metadata?: Json | null
          title?: string
          transaction_id?: string | null
          type?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_transaction_id_fkey"
            columns: ["transaction_id"]
            isOneToOne: false
            referencedRelation: "points_transactions"
            referencedColumns: ["id"]
          },
        ]
      }
      points_audit_logs: {
        Row: {
          amount: number
          created_at: string
          id: string
          reason: string
          trigger_name: string
          user_id: string | null
        }
        Insert: {
          amount: number
          created_at?: string
          id?: string
          reason: string
          trigger_name: string
          user_id?: string | null
        }
        Update: {
          amount?: number
          created_at?: string
          id?: string
          reason?: string
          trigger_name?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "points_audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "leaderboard"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "points_audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_referrals_detailed"
            referencedColumns: ["referee_id"]
          },
          {
            foreignKeyName: "points_audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "points_audit_logs_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_ranks"
            referencedColumns: ["user_id"]
          },
        ]
      }
      points_transactions: {
        Row: {
          amount: number
          created_at: string
          description: string | null
          id: string
          source_id: string | null
          status: string | null
          type: string
          user_id: string
        }
        Insert: {
          amount: number
          created_at?: string
          description?: string | null
          id?: string
          source_id?: string | null
          status?: string | null
          type: string
          user_id: string
        }
        Update: {
          amount?: number
          created_at?: string
          description?: string | null
          id?: string
          source_id?: string | null
          status?: string | null
          type?: string
          user_id?: string
        }
        Relationships: []
      }
      profiles: {
        Row: {
          avatar_url: string | null
          created_at: string
          email: string
          email_notifications: boolean | null
          facebook_handle: string | null
          fingerprint: string | null
          full_name: string | null
          has_claimed_welcome_bonus: boolean | null
          id: string
          instagram_handle: string | null
          last_ip: string | null
          phone_number: string | null
          points_balance: number
          push_notifications: boolean | null
          referral_clicks: number | null
          referral_code: string | null
          referral_code_used: string | null
          referred_by: string | null
          telegram_handle: string | null
          twitter_handle: string | null
          updated_at: string
          username: string | null
          welcome_banner_dismissed: boolean | null
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          email: string
          email_notifications?: boolean | null
          facebook_handle?: string | null
          fingerprint?: string | null
          full_name?: string | null
          has_claimed_welcome_bonus?: boolean | null
          id: string
          instagram_handle?: string | null
          last_ip?: string | null
          phone_number?: string | null
          points_balance?: number
          push_notifications?: boolean | null
          referral_clicks?: number | null
          referral_code?: string | null
          referral_code_used?: string | null
          referred_by?: string | null
          telegram_handle?: string | null
          twitter_handle?: string | null
          updated_at?: string
          username?: string | null
          welcome_banner_dismissed?: boolean | null
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          email?: string
          email_notifications?: boolean | null
          facebook_handle?: string | null
          fingerprint?: string | null
          full_name?: string | null
          has_claimed_welcome_bonus?: boolean | null
          id?: string
          instagram_handle?: string | null
          last_ip?: string | null
          phone_number?: string | null
          points_balance?: number
          push_notifications?: boolean | null
          referral_clicks?: number | null
          referral_code?: string | null
          referral_code_used?: string | null
          referred_by?: string | null
          telegram_handle?: string | null
          twitter_handle?: string | null
          updated_at?: string
          username?: string | null
          welcome_banner_dismissed?: boolean | null
        }
        Relationships: []
      }
      redemptions: {
        Row: {
          created_at: string
          fraud_details: Json | null
          fraud_score: number | null
          id: string
          is_flagged: boolean | null
          rejection_reason: string | null
          reward_id: string
          status: string
          updated_at: string | null
          user_id: string
        }
        Insert: {
          created_at?: string
          fraud_details?: Json | null
          fraud_score?: number | null
          id?: string
          is_flagged?: boolean | null
          rejection_reason?: string | null
          reward_id: string
          status?: string
          updated_at?: string | null
          user_id: string
        }
        Update: {
          created_at?: string
          fraud_details?: Json | null
          fraud_score?: number | null
          id?: string
          is_flagged?: boolean | null
          rejection_reason?: string | null
          reward_id?: string
          status?: string
          updated_at?: string | null
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "redemptions_reward_id_fkey"
            columns: ["reward_id"]
            isOneToOne: false
            referencedRelation: "rewards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "redemptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "leaderboard"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "redemptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_referrals_detailed"
            referencedColumns: ["referee_id"]
          },
          {
            foreignKeyName: "redemptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "redemptions_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_ranks"
            referencedColumns: ["user_id"]
          },
        ]
      }
      referrals: {
        Row: {
          created_at: string | null
          referee_id: string
          referrer_id: string | null
        }
        Insert: {
          created_at?: string | null
          referee_id: string
          referrer_id?: string | null
        }
        Update: {
          created_at?: string | null
          referee_id?: string
          referrer_id?: string | null
        }
        Relationships: []
      }
      rewards: {
        Row: {
          category: string | null
          cost_points: number
          created_at: string
          description: string | null
          id: string
          image_url: string | null
          is_active: boolean
          stock_count: number | null
          title: string
        }
        Insert: {
          category?: string | null
          cost_points: number
          created_at?: string
          description?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          stock_count?: number | null
          title: string
        }
        Update: {
          category?: string | null
          cost_points?: number
          created_at?: string
          description?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean
          stock_count?: number | null
          title?: string
        }
        Relationships: []
      }
      role_permissions: {
        Row: {
          created_at: string | null
          id: string
          is_enabled: boolean | null
          role: Database["public"]["Enums"]["app_role"]
          tab_name: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          id?: string
          is_enabled?: boolean | null
          role: Database["public"]["Enums"]["app_role"]
          tab_name: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          id?: string
          is_enabled?: boolean | null
          role?: Database["public"]["Enums"]["app_role"]
          tab_name?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      signup_otps: {
        Row: {
          attempts: number
          code_hash: string
          created_at: string
          email: string
          expires_at: string
        }
        Insert: {
          attempts?: number
          code_hash: string
          created_at?: string
          email: string
          expires_at: string
        }
        Update: {
          attempts?: number
          code_hash?: string
          created_at?: string
          email?: string
          expires_at?: string
        }
        Relationships: []
      }
      task_submissions: {
        Row: {
          admin_note: string | null
          created_at: string | null
          id: string
          status: string
          task_id: string
          user_id: string
          verified_at: string | null
        }
        Insert: {
          admin_note?: string | null
          created_at?: string | null
          id?: string
          status: string
          task_id: string
          user_id: string
          verified_at?: string | null
        }
        Update: {
          admin_note?: string | null
          created_at?: string | null
          id?: string
          status?: string
          task_id?: string
          user_id?: string
          verified_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "task_submissions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "repeatable_task_stats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "leaderboard"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_referrals_detailed"
            referencedColumns: ["referee_id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_ranks"
            referencedColumns: ["user_id"]
          },
        ]
      }
      tasks: {
        Row: {
          category: string | null
          created_at: string
          description: string | null
          icon_name: string | null
          id: string
          is_active: boolean
          is_featured: boolean | null
          is_repeatable: boolean | null
          link_url: string | null
          points: number
          title: string
          vast_tag_url: string | null
          verification_required: boolean | null
          video_ad_count: number | null
        }
        Insert: {
          category?: string | null
          created_at?: string
          description?: string | null
          icon_name?: string | null
          id?: string
          is_active?: boolean
          is_featured?: boolean | null
          is_repeatable?: boolean | null
          link_url?: string | null
          points: number
          title: string
          vast_tag_url?: string | null
          verification_required?: boolean | null
          video_ad_count?: number | null
        }
        Update: {
          category?: string | null
          created_at?: string
          description?: string | null
          icon_name?: string | null
          id?: string
          is_active?: boolean
          is_featured?: boolean | null
          is_repeatable?: boolean | null
          link_url?: string | null
          points?: number
          title?: string
          vast_tag_url?: string | null
          verification_required?: boolean | null
          video_ad_count?: number | null
        }
        Relationships: []
      }
      user_roles: {
        Row: {
          id: string
          role: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Insert: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id: string
        }
        Update: {
          id?: string
          role?: Database["public"]["Enums"]["app_role"]
          user_id?: string
        }
        Relationships: []
      }
      user_streaks: {
        Row: {
          current_streak: number
          last_activity_at: string
          longest_streak: number
          user_id: string
        }
        Insert: {
          current_streak?: number
          last_activity_at?: string
          longest_streak?: number
          user_id: string
        }
        Update: {
          current_streak?: number
          last_activity_at?: string
          longest_streak?: number
          user_id?: string
        }
        Relationships: []
      }
      video_ad_progress: {
        Row: {
          created_at: string | null
          id: string
          last_watch_at: string | null
          task_id: string
          user_id: string
          watch_count: number
        }
        Insert: {
          created_at?: string | null
          id?: string
          last_watch_at?: string | null
          task_id: string
          user_id: string
          watch_count?: number
        }
        Update: {
          created_at?: string | null
          id?: string
          last_watch_at?: string | null
          task_id?: string
          user_id?: string
          watch_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "video_ad_progress_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "repeatable_task_stats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "video_ad_progress_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
      video_watch_sessions: {
        Row: {
          consumed: boolean
          created_at: string
          expires_at: string
          id: string
          min_watch_seconds: number
          task_id: string
          user_id: string
        }
        Insert: {
          consumed?: boolean
          created_at?: string
          expires_at?: string
          id?: string
          min_watch_seconds?: number
          task_id: string
          user_id: string
        }
        Update: {
          consumed?: boolean
          created_at?: string
          expires_at?: string
          id?: string
          min_watch_seconds?: number
          task_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "video_watch_sessions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "repeatable_task_stats"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "video_watch_sessions_task_id_fkey"
            columns: ["task_id"]
            isOneToOne: false
            referencedRelation: "tasks"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      daily_task_completions: {
        Row: {
          completion_date: string | null
          count: number | null
        }
        Relationships: []
      }
      global_referral_stats: {
        Row: {
          completed_referrals: number | null
          total_referrals: number | null
          total_referrers: number | null
        }
        Relationships: []
      }
      leaderboard: {
        Row: {
          avatar_url: string | null
          full_name: string | null
          id: string | null
          points_balance: number | null
          rank: number | null
          username: string | null
        }
        Relationships: []
      }
      my_referrals_detailed: {
        Row: {
          avatar_url: string | null
          full_name: string | null
          joined_at: string | null
          referee_id: string | null
          referrer_id: string | null
          status: string | null
          username: string | null
        }
        Relationships: []
      }
      referral_stats_summary: {
        Row: {
          completed_referrals: number | null
          points_earned: number | null
          total_referrals: number | null
          user_id: string | null
        }
        Relationships: []
      }
      referrals_with_profiles: {
        Row: {
          created_at: string | null
          referee_created_at: string | null
          referee_email: string | null
          referee_full_name: string | null
          referee_has_claimed_welcome_bonus: boolean | null
          referee_id: string | null
          referee_telegram_handle: string | null
          referee_twitter_handle: string | null
          referee_username: string | null
          referrer_avatar_url: string | null
          referrer_email: string | null
          referrer_full_name: string | null
          referrer_id: string | null
          referrer_points_balance: number | null
          referrer_referral_code: string | null
          referrer_username: string | null
        }
        Relationships: []
      }
      repeatable_task_stats: {
        Row: {
          claims_per_user: number | null
          id: string | null
          title: string | null
          total_claims: number | null
          unique_users: number | null
        }
        Relationships: []
      }
      user_daily_task_counts: {
        Row: {
          daily_count: number | null
          user_id: string | null
        }
        Relationships: [
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "leaderboard"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "my_referrals_detailed"
            referencedColumns: ["referee_id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "task_submissions_user_id_profiles_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "user_ranks"
            referencedColumns: ["user_id"]
          },
        ]
      }
      user_ranks: {
        Row: {
          rank_level: number | null
          rank_name: string | null
          referral_count: number | null
          user_id: string | null
          username: string | null
        }
        Relationships: []
      }
    }
    Functions: {
      admin_adjust_points: {
        Args: {
          _amount: number
          _description: string
          _type: string
          _user_id: string
        }
        Returns: Json
      }
      admin_revoke_task_submission: {
        Args: { _admin_note?: string; _submission_id: string }
        Returns: Json
      }
      check_referral_code: {
        Args: { _code: string; _user_id?: string }
        Returns: {
          is_valid: boolean
          message: string
          username: string
        }[]
      }
      check_username_available: {
        Args: { _username: string }
        Returns: boolean
      }
      claim_daily_reward: { Args: { _user_id: string }; Returns: Json }
      claim_welcome_bonus: { Args: { _user_id: string }; Returns: Json }
      get_daily_task_completions: {
        Args: {
          end_date: string
          filter_task_id?: string
          granularity?: string
          start_date: string
        }
        Returns: {
          completion_date: string
          count: number
        }[]
      }
      get_funnel_stats: {
        Args: { end_date: string; start_date: string }
        Returns: {
          bonuses: number
          referrals: number
          signups: number
        }[]
      }
      get_my_referees: {
        Args: never
        Returns: {
          avatar_url: string
          created_at: string
          full_name: string
          has_phone: boolean
          has_social: boolean
          id: string
          username: string
        }[]
      }
      get_repeatable_task_stats: {
        Args: { end_date: string; filter_task_id?: string; start_date: string }
        Returns: {
          claims_per_user: number
          id: string
          title: string
          total_claims: number
          unique_users: number
        }[]
      }
      handle_admin_points_adjustment: {
        Args: {
          p_action_type: string
          p_amount: number
          p_reason: string
          p_target_user_id: string
        }
        Returns: undefined
      }
      has_completed_social_profile: {
        Args: { _user_id: string }
        Returns: boolean
      }
      has_role: {
        Args: {
          _role: Database["public"]["Enums"]["app_role"]
          _user_id: string
        }
        Returns: boolean
      }
      increment_referral_clicks: {
        Args: { target_referral_code: string }
        Returns: undefined
      }
      is_profile_complete: { Args: { p_profile_id: string }; Returns: boolean }
      lookup_login_email: { Args: { _username: string }; Returns: string }
      process_redemption_status_change: {
        Args: {
          _new_status: string
          _redemption_id: string
          _rejection_reason?: string
        }
        Returns: Json
      }
      record_video_watch: {
        Args: { _session_id: string; _task_id: string; _user_id: string }
        Returns: Json
      }
      redeem_reward: { Args: { _reward_id: string }; Returns: Json }
      send_user_notification: {
        Args: {
          _message: string
          _metadata?: Json
          _title: string
          _type?: string
          _user_id: string
        }
        Returns: Json
      }
      start_video_watch_session: {
        Args: { _task_id: string; _user_id: string }
        Returns: Json
      }
      submit_task: {
        Args: { _task_id: string; _user_id: string }
        Returns: Json
      }
      sync_points_balance: { Args: { p_user_id: string }; Returns: undefined }
      verify_task_submission: {
        Args: {
          _admin_note?: string
          _approve: boolean
          _submission_id: string
        }
        Returns: Json
      }
    }
    Enums: {
      app_role: "admin" | "user" | "tasker" | "moderator" | "task_manager"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      app_role: ["admin", "user", "tasker", "moderator", "task_manager"],
    },
  },
} as const
