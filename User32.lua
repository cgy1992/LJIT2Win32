
local ffi = require "ffi"

local user32_ffi = require "user32_ffi"
local User32Lib = ffi.load("User32");

--[=[
ffi.cdef[[
typedef struct _WindowClass {
	WNDPROC	MessageProc;
	ATOM	Registration;
	HINSTANCE	AppInstance;
	char *	ClassName;
	int X;
	int Y;
	int Width;
	int Height;
	char *Title;
} User32WindowClass;
]]
--]=]

ffi.cdef[[
typedef struct _User32Window {
	HWND	Handle;
} NativeWindow, *PNativeWindow;
]]

NativeWindow = ffi.typeof("NativeWindow")
NativeWindow_mt = {
	__index = {
		Show = function(self)
			User32Lib.ShowWindow(self.Handle, C.SW_SHOW)
		end,

		Update = function(self)
			User32Lib.UpdateWindow(self.Handle)
		end,

		GetTitle = function(self)
			local buf = ffi.new("char[?]", 256)
			local lbuf = ffi.cast("intptr_t", buf)
			if User32Lib.SendMessageA(self.WindowHandle, C.WM_GETTEXT, 255, lbuf) ~= 0 then
				return ffi.string(buf)
			end
		end,

		OnCreate = function(self)
			print("User32Window:OnCreate")
			return 0
		end,
	}
}
NativeWindow = ffi.metatype(NativeWindow, NativeWindow_mt)




function User32_MsgProc(hwnd, msg, wparam, lparam)
--print("User32_MsgProc: ", msg)
	if (msg == C.WM_CREATE) then
		--print("WM_CREATE")

		local crstruct = ffi.cast("LPCREATESTRUCTA", lparam)

		--print(crstruct.lpCreateParams)
		local win = ffi.cast("PUser32Window", crstruct.lpCreateParams)
		return win:OnCreate()
	elseif (msg == C.WM_DESTROY) then
		--print("WM_DESTROY")
		C.PostQuitMessage(0)
		return 0
	end

	local retValue = User32Lib.DefWindowProcA(hwnd, msg, wparam, lparam)

	return retValue;
end


User32MSGHandler = {}
User32MSGHandler_mt = {
	__index = User32MSGHandler,
}



User32MSGHandler.new = function(classname, msgproc, classStyle)
	local appInstance = kernel32.GetModuleHandleA(nil)
	msgproc = msgproc or User32_MsgProc
	classStyle = classStyle or bit.bor(user32_ffi.CS_HREDRAW, user32_ffi.CS_VREDRAW, user32_ffi.CS_OWNDC);

	local self = {}
	self.AppInstance = appInstance
	self.ClassName = ffi.cast("const char *", classname)
	self.MessageProc = msgproc

	setmetatable(self, User32MSGHandler_mt);

	local winClass = ffi.new('WNDCLASSEXA', {
		cbSize = ffi.sizeof("WNDCLASSEXA");
		style = classStyle;
		lpfnWndProc = self.MessageProc;
		cbClsExtra = 0;
		cbWndExtra = 0;
		hInstance = self.AppInstance;
		hIcon = nil;
		hCursor = nil;
		hbrBackground = nil;
		lpszMenuName = nil;
		lpszClassName = self.ClassName;
		hIconSm = nil;
		})

	self.Registration = User32Lib.RegisterClassExA(winClass)

	if (self.Registration == 0) then
		print("Registration error")
		--print(C.GetLastError())
	end

	return self
end

User32MSGHandler.CreateHandler = function(self, title, x, y, width, height, windowStyle)
	x = x or 10
	y = y or 10
	width = width or 320
	height = height or 240
	windowStyle = windowStyle or C.WS_OVERLAPPEDWINDOW

	self.Title = ffi.cast("const char *", title)

	local dwExStyle =  bit.bor(user32_ffi.WS_EX_APPWINDOW, user32_ffi.WS_EX_WINDOWEDGE)


	local win = ffi.new("NativeWindow")

	local hWnd = User32Lib.CreateWindowExA(
				0,
				self.ClassName,
				self.Title,
				windowStyle,
				x,
				y,
				width,
				height,
				nil,
				nil,
				self.AppInstance,
				win)

	if hWnd == nil then
		print("unable to create window")
	else
		win.Handle = hWnd
	end

	return win
end

return {
	FFI = user32_ffi,
	Lib = User32Lib,
	
	User32MSGHandler = User32MSGHandler,
	NativeWindow = NativeWindow,
}