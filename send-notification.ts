// Supabase Edge Function: send-notification
// Deploy to: supabase functions deploy send-notification

import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { orderId, userType, userId, title, message } = await req.json()
    
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get FCM token
    let fcmToken = null
    if (userType === 'customer') {
      const { data } = await supabase.from('customers').select('fcm_token').eq('customer_id', userId).single()
      fcmToken = data?.fcm_token
    } else if (userType === 'chef') {
      const { data } = await supabase.from('chefs').select('fcm_token').eq('chef_id', userId).single()
      fcmToken = data?.fcm_token
    } else if (userType === 'delivery') {
      const { data } = await supabase.from('deliverers').select('fcm_token').eq('deliverer_id', userId).single()
      fcmToken = data?.fcm_token
    }

    if (!fcmToken) {
      throw new Error('FCM token not found')
    }

    // Send FCM notification
    const fcmResponse = await fetch('https://fcm.googleapis.com/fcm/send', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `key=${Deno.env.get('FCM_SERVER_KEY')}`
      },
      body: JSON.stringify({
        to: fcmToken,
        notification: { title, body: message },
        data: { orderId: orderId?.toString() }
      })
    })

    // Log notification
    await supabase.from('notifications').insert({
      user_type: userType,
      user_id: userId,
      order_id: orderId,
      title,
      message,
      is_sent: fcmResponse.ok
    })

    return new Response(JSON.stringify({ success: fcmResponse.ok }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    })
  }
})