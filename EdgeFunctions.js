// ============================================
// PAHAD FOOD - SUPABASE EDGE FUNCTIONS
// ============================================

// This file contains all the Edge Functions needed for Pahad Food
// Each function should be deployed separately to Supabase

// ============================================
// FUNCTION 1: create-order
// Path: supabase/functions/create-order/index.ts
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    const { 
      customer_id, 
      city_id, 
      delivery_type, 
      items, 
      special_instructions,
      delivery_instructions 
    } = await req.json()

    // Calculate totals
    let subtotal = 0
    const itemsWithChef = []

    for (const item of items) {
      const { data: menuItem } = await supabaseClient
        .from('menu')
        .select('*, chefs(chef_id)')
        .eq('item_id', item.item_id)
        .single()

      if (menuItem) {
        const itemTotal = menuItem.price * item.quantity
        subtotal += itemTotal
        
        itemsWithChef.push({
          item_id: item.item_id,
          chef_id: menuItem.chefs.chef_id,
          quantity: item.quantity,
          price_at_order_time: menuItem.price,
          chef_amount: itemTotal
        })
      }
    }

    const delivery_amount = delivery_type === 'delivery' ? 30 : 0
    const platform_fee = 10
    const total_amount = subtotal + delivery_amount + platform_fee

    // Create order
    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .insert({
        customer_id,
        city_id,
        delivery_type,
        current_status: 'placed',
        delivery_amount,
        platform_fee,
        total_amount,
        special_instructions,
        delivery_instructions
      })
      .select()
      .single()

    if (orderError) throw orderError

    // Create order items
    const orderItems = itemsWithChef.map(item => ({
      ...item,
      order_id: order.order_id
    }))

    const { error: itemsError } = await supabaseClient
      .from('order_items')
      .insert(orderItems)

    if (itemsError) throw itemsError

    // Add to order status history
    await supabaseClient
      .from('order_status_history')
      .insert({
        order_id: order.order_id,
        status: 'placed',
        changed_by: 'customer'
      })

    // Send notifications to chefs
    const uniqueChefIds = [...new Set(itemsWithChef.map(item => item.chef_id))]
    
    for (const chef_id of uniqueChefIds) {
      await supabaseClient
        .from('notifications')
        .insert({
          user_type: 'chef',
          user_id: chef_id,
          order_id: order.order_id,
          title: 'New Order',
          message: `You have a new order #${order.order_id}`
        })
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        order_id: order.order_id,
        total_amount 
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

// ============================================
// FUNCTION 2: update-order-status
// Path: supabase/functions/update-order-status/index.ts
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    const { order_id, new_status, changed_by, delivery_person_id } = await req.json()

    // Update order status
    const updateData: any = { current_status: new_status }
    if (delivery_person_id) {
      updateData.delivery_person_id = delivery_person_id
    }

    const { data: order, error: orderError } = await supabaseClient
      .from('orders')
      .update(updateData)
      .eq('order_id', order_id)
      .select('*, customers(*), order_items(*, chefs(*))')
      .single()

    if (orderError) throw orderError

    // Add to status history
    await supabaseClient
      .from('order_status_history')
      .insert({
        order_id,
        status: new_status,
        changed_by
      })

    // Send notifications based on status
    let notificationTitle = ''
    let notificationMessage = ''

    switch (new_status) {
      case 'accepted':
        notificationTitle = 'Order Accepted'
        notificationMessage = `Your order #${order_id} has been accepted and is being prepared`
        await supabaseClient
          .from('notifications')
          .insert({
            user_type: 'customer',
            user_id: order.customer_id,
            order_id,
            title: notificationTitle,
            message: notificationMessage
          })
        break

      case 'prepared':
        notificationTitle = 'Order Ready'
        notificationMessage = `Your order #${order_id} is ready`
        
        // Notify customer
        await supabaseClient
          .from('notifications')
          .insert({
            user_type: 'customer',
            user_id: order.customer_id,
            order_id,
            title: notificationTitle,
            message: notificationMessage
          })

        // Notify delivery person if assigned
        if (order.delivery_person_id && order.delivery_type === 'delivery') {
          await supabaseClient
            .from('notifications')
            .insert({
              user_type: 'delivery',
              user_id: order.delivery_person_id,
              order_id,
              title: 'Order Ready for Pickup',
              message: `Order #${order_id} is ready for pickup`
            })
        }
        break

      case 'picked_up':
        notificationTitle = 'Order Picked Up'
        notificationMessage = `Your order #${order_id} is on the way`
        await supabaseClient
          .from('notifications')
          .insert({
            user_type: 'customer',
            user_id: order.customer_id,
            order_id,
            title: notificationTitle,
            message: notificationMessage
          })
        break

      case 'delivered':
        notificationTitle = 'Order Delivered'
        notificationMessage = `Your order #${order_id} has been delivered. Enjoy your meal!`
        await supabaseClient
          .from('notifications')
          .insert({
            user_type: 'customer',
            user_id: order.customer_id,
            order_id,
            title: notificationTitle,
            message: notificationMessage
          })
        break

      case 'cancelled':
        notificationTitle = 'Order Cancelled'
        notificationMessage = `Your order #${order_id} has been cancelled`
        await supabaseClient
          .from('notifications')
          .insert({
            user_type: 'customer',
            user_id: order.customer_id,
            order_id,
            title: notificationTitle,
            message: notificationMessage
          })
        break
    }

    return new Response(
      JSON.stringify({ success: true, order }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

// ============================================
// FUNCTION 3: send-notification
// Path: supabase/functions/send-notification/index.ts
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
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
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_ANON_KEY') ?? '',
    )

    const { notification_id } = await req.json()

    // Get notification details
    const { data: notification, error: notifError } = await supabaseClient
      .from('notifications')
      .select(`
        *,
        customers(fcm_token),
        chefs(fcm_token),
        deliverers(fcm_token)
      `)
      .eq('notification_id', notification_id)
      .single()

    if (notifError) throw notifError

    // Get FCM token based on user type
    let fcmToken = null
    switch (notification.user_type) {
      case 'customer':
        fcmToken = notification.customers?.fcm_token
        break
      case 'chef':
        fcmToken = notification.chefs?.fcm_token
        break
      case 'delivery':
        fcmToken = notification.deliverers?.fcm_token
        break
    }

    if (fcmToken) {
      // Send FCM notification using Firebase Admin SDK
      const FCM_SERVER_KEY = Deno.env.get('FCM_SERVER_KEY')
      
      const response = await fetch('https://fcm.googleapis.com/fcm/send', {
        method: 'POST',
        headers: {
          'Authorization': `key=${FCM_SERVER_KEY}`,
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          to: fcmToken,
          notification: {
            title: notification.title,
            body: notification.message,
          },
          data: {
            order_id: notification.order_id,
            user_type: notification.user_type
          }
        })
      })

      if (response.ok) {
        // Mark notification as sent
        await supabaseClient
          .from('notifications')
          .update({ is_sent: true })
          .eq('notification_id', notification_id)
      }
    }

    return new Response(
      JSON.stringify({ success: true }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})

// ============================================
// FUNCTION 4: auto-expire-orders
// Path: supabase/functions/auto-expire-orders/index.ts
// This runs on a schedule (every 1 minute)
// ============================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

serve(async (req) => {
  try {
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Get orders that are 'placed' for more than 10 minutes
    const tenMinutesAgo = new Date(Date.now() - 10 * 60 * 1000).toISOString()

    const { data: expiredOrders, error: fetchError } = await supabaseClient
      .from('orders')
      .select('*')
      .eq('current_status', 'placed')
      .lt('created_at', tenMinutesAgo)

    if (fetchError) throw fetchError

    // Auto-cancel expired orders
    for (const order of expiredOrders || []) {
      await supabaseClient
        .from('orders')
        .update({ current_status: 'cancelled' })
        .eq('order_id', order.order_id)

      await supabaseClient
        .from('order_status_history')
        .insert({
          order_id: order.order_id,
          status: 'cancelled',
          changed_by: 'system'
        })

      // Notify customer
      await supabaseClient
        .from('notifications')
        .insert({
          user_type: 'customer',
          user_id: order.customer_id,
          order_id: order.order_id,
          title: 'Order Expired',
          message: `Order #${order.order_id} was automatically cancelled due to no chef response`
        })
    }

    return new Response(
      JSON.stringify({ 
        success: true, 
        expired_count: expiredOrders?.length || 0 
      }),
      { headers: { 'Content-Type': 'application/json' } }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { headers: { 'Content-Type': 'application/json' }, status: 400 }
    )
  }
})