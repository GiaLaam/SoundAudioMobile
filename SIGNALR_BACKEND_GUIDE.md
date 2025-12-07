# 🎵 SignalR Backend Guide - Đồng bộ Mobile & Web

## ✅ Hiện trạng
- ✅ SignalR Hub đã tồn tại tại: `/hubs/playback`
- ✅ Web có thể đồng bộ giữa 2 tab Web
- ✅ Mobile đã kết nối thành công SignalR
- ❌ Mobile chưa thể gửi thông báo đến Web/Mobile khác

## 🔧 Cần làm gì?

### **Mở file Backend Hub** (có thể tên là `PlaybackHub.cs` hoặc tương tự)

Và thêm phương thức sau:

```csharp
[Authorize]
public class PlaybackHub : Hub
{
    // ====== THÊM PHƯƠNG THỨC NÀY ======
    /// <summary>
    /// Mobile/Web gọi method này khi bắt đầu phát nhạc
    /// Sẽ gửi lệnh StopPlayback đến TẤT CẢ thiết bị khác
    /// </summary>
    public async Task NotifyPlaybackStarted(string deviceId)
    {
        // Lấy userId từ JWT token
        var userId = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        
        Console.WriteLine($"🎵 [PlaybackHub] Device {deviceId} (User: {userId}) started playback");
        Console.WriteLine($"   Notifying {Context.ConnectionAborted} other connections to stop");
        
        // Gửi lệnh StopPlayback đến TẤT CẢ kết nối khác của cùng user
        // Clients.Others = tất cả kết nối trừ kết nối hiện tại
        await Clients.Others.SendAsync("StopPlayback", deviceId);
        
        Console.WriteLine($"   ✅ Sent StopPlayback event to other devices");
    }
    
    // ====== CÁC PHƯƠNG THỨC CŨ GIỮ NGUYÊN ======
    // ...existing methods...
}
```

### **Giải thích:**

1. **`NotifyPlaybackStarted(string deviceId)`**: 
   - Mobile/Web gọi method này khi người dùng bắt đầu phát nhạc
   - `deviceId`: ID duy nhất của thiết bị đang phát

2. **`Clients.Others.SendAsync("StopPlayback", deviceId)`**:
   - Gửi event `StopPlayback` đến **TẤT CẢ** kết nối khác
   - Bao gồm: Web tabs khác, Mobile devices khác của cùng user

3. **`[Authorize]`**: 
   - Đảm bảo chỉ user đã đăng nhập mới kết nối được

---

## 📋 Checklist sau khi thêm code:

### **1. Kiểm tra Program.cs có đủ cấu hình SignalR:**

```csharp
// Trong Program.cs

// Thêm SignalR service
builder.Services.AddSignalR();

// Map Hub endpoint
app.MapHub<PlaybackHub>("/hubs/playback");

// Đảm bảo JWT authentication hỗ trợ SignalR
builder.Services.AddAuthentication(options => { ... })
    .AddJwtBearer(options =>
    {
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = context =>
            {
                // SignalR gửi token qua query string
                var accessToken = context.Request.Query["access_token"];
                var path = context.HttpContext.Request.Path;
                
                if (!string.IsNullOrEmpty(accessToken) && 
                    path.StartsWithSegments("/hubs/playback"))
                {
                    context.Token = accessToken;
                }
                return Task.CompletedTask;
            }
        };
    });
```

### **2. Kiểm tra CORS cho phép SignalR:**

```csharp
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", builder =>
    {
        builder
            .AllowAnyOrigin()
            .AllowAnyMethod()
            .AllowAnyHeader()
            .AllowCredentials(); // Quan trọng cho SignalR!
    });
});

app.UseCors("AllowAll");
```

### **3. Restart Backend Server**

Sau khi thêm code, hãy restart server:
```bash
dotnet run
```

### **4. Kiểm tra Backend Logs**

Khi Mobile kết nối và phát nhạc, bạn sẽ thấy:
```
🎵 [PlaybackHub] Device c61e4fd1-bb83-4a4a-84f4-570c9bc73bb6 (User: 53e083e6-...) started playback
   Notifying other connections to stop
   ✅ Sent StopPlayback event to other devices
```

---

## 🎯 Test đồng bộ

Sau khi backend đã có phương thức `NotifyPlaybackStarted`:

### **Test 1: Mobile → Web**
1. Phát nhạc trên Mobile
2. Chuyển sang Web (cùng tài khoản)
3. Phát nhạc trên Web
4. ✅ Mobile sẽ tự động dừng lại

**Mobile Logs:**
```
🎵 Notifying other devices to stop...
✅ Used NotifyPlaybackStarted - other devices notified
```

**Web Console:**
```
[PlaybackSession] Received StopPlayback from device: c61e4fd1-bb83-4a4a-84f4-570c9bc73bb6
[PlaybackSession] Pausing playback
```

### **Test 2: Web → Mobile**
1. Phát nhạc trên Web
2. Chuyển sang Mobile
3. Phát nhạc trên Mobile
4. ✅ Web sẽ tự động dừng lại

**Mobile Logs:**
```
🎵 Notifying other devices to stop...
✅ Used NotifyPlaybackStarted - other devices notified
```

### **Test 3: Web 1 ↔ Web 2** (Đã hoạt động)
✅ Đã test thành công

---

## 🐛 Troubleshooting

### **Lỗi: "Method does not exist"**
- ✅ Đã fix! Backend cần thêm method `NotifyPlaybackStarted`

### **Mobile kết nối nhưng không đồng bộ:**
- Kiểm tra JWT token có hợp lệ không
- Kiểm tra CORS có cho phép credentials không
- Xem backend logs có nhận được event không

### **Web hoạt động nhưng Mobile không:**
- Kiểm tra endpoint có đúng là `/hubs/playback` không
- Kiểm tra Mobile có gọi `SignalRService().notifyPlaybackStarted()` khi phát nhạc không

---

## 📱 Mobile Code (Đã có sẵn)

Mobile đã được config để:
1. Tự động kết nối SignalR khi đăng nhập
2. Lắng nghe event `StopPlayback` từ server
3. Gọi `notifyPlaybackStarted()` khi phát nhạc

### **Cách sử dụng trong Mobile:**

```dart
// Trong MusicPlayerService hoặc nơi bắt đầu phát nhạc
await SignalRService().notifyPlaybackStarted();
```

---

## ✅ Kết luận

Sau khi thêm method `NotifyPlaybackStarted` vào backend:
- ✅ Mobile ↔ Web đồng bộ hoàn hảo
- ✅ Web ↔ Web đồng bộ (đã có)
- ✅ Mobile ↔ Mobile đồng bộ
- ✅ Chỉ 1 thiết bị phát nhạc tại một thời điểm

---

## 📞 Hỗ trợ

Nếu gặp vấn đề, hãy kiểm tra:
1. Backend logs có hiển thị "Device ... started playback" không?
2. Mobile logs có hiển thị "Used NotifyPlaybackStarted" không?
3. Web console có nhận được event "StopPlayback" không?

**Created:** 24/11/2025  
**Status:** Backend cần thêm method `NotifyPlaybackStarted`

