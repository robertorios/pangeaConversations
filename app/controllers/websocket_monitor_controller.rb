class WebsocketMonitorController < ApplicationController
  # Class variable to track pause state
  @@paused = false
  def index
    # Check if monitoring is paused
    if @@paused
      render json: {
        total_connections: 0,
        connections: [],
        paused: true,
        message: "WebSocket monitoring is PAUSED",
        timestamp: Time.current.iso8601
      }
      return
    end
    
    # Get Action Cable server statistics
    server = ActionCable.server
    
    # Count active connections
    active_connections = server.connections.size
    
    # Get connection details
    connection_details = server.connections.map do |connection|
      {
        id: connection.current_user_id,
        subscriptions: connection.subscriptions.instance_variable_get(:@subscriptions).size,
        channels: connection.subscriptions.instance_variable_get(:@subscriptions).keys
      }
    end
    
    render json: {
      total_connections: active_connections,
      connections: connection_details,
      paused: false,
      timestamp: Time.current.iso8601
    }
  end
  
  def stats
    # Check if monitoring is paused
    if @@paused
      render json: {
        total_connections: 0,
        total_subscriptions: 0,
        channels: {},
        paused: true,
        message: "WebSocket monitoring is PAUSED",
        timestamp: Time.current.iso8601
      }
      return
    end
    
    # More detailed statistics
    server = ActionCable.server
    
    stats = {
      total_connections: server.connections.size,
      total_subscriptions: server.connections.sum { |c| c.subscriptions.instance_variable_get(:@subscriptions).size },
      channels: {},
      paused: false,
      timestamp: Time.current.iso8601
    }
    
    # Count subscriptions per channel
    server.connections.each do |connection|
      connection.subscriptions.instance_variable_get(:@subscriptions).each do |identifier, subscription|
        channel_name = subscription.class.name
        stats[:channels][channel_name] ||= 0
        stats[:channels][channel_name] += 1
      end
    end
    
    render json: stats
  end
  
  # NEW: Stop all WebSocket connections
  def stop_all
    server = ActionCable.server
    connection_count = server.connections.size
    
    # Close all connections
    server.connections.each do |connection|
      connection.close
    end
    
    render json: {
      message: "Stopped #{connection_count} WebSocket connections",
      timestamp: Time.current.iso8601
    }
  end
  
  # NEW: Stop specific user's connections
  def stop_user
    user_id = params[:user_id]
    server = ActionCable.server
    stopped_count = 0
    
    server.connections.each do |connection|
      # Check if this connection has subscriptions for the specified user
      connection.subscriptions.instance_variable_get(:@subscriptions).each do |identifier, subscription|
        if subscription.params['user_id'] == user_id.to_s
          connection.close
          stopped_count += 1
          break
        end
      end
    end
    
    render json: {
      message: "Stopped #{stopped_count} connections for user #{user_id}",
      timestamp: Time.current.iso8601
    }
  end
  
  # NEW: Pause WebSocket monitoring
  def pause
    @@paused = true
    render json: {
      message: "WebSocket monitoring PAUSED",
      paused: true,
      timestamp: Time.current.iso8601
    }
  end
  
  # NEW: Resume WebSocket monitoring
  def resume
    @@paused = false
    render json: {
      message: "WebSocket monitoring RESUMED",
      paused: false,
      timestamp: Time.current.iso8601
    }
  end
end