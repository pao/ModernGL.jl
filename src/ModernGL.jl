module ModernGL


function glXGetProcAddress(glFuncName::ASCIIString)
    ccall((:glXGetProcAddress, "libGL.so.1"), Ptr{Void}, (Ptr{Uint8},), glFuncName)
end

function NSGetProcAddress(glFuncName::ASCIIString)
#=
    if this approach doesn't work, I might need to wrap this:
    GLFWglproc _glfwPlatformGetProcAddress(const char* procname)
    {
        CFStringRef symbolName = CFStringCreateWithCString(kCFAllocatorDefault,
                                                           procname,
                                                           kCFStringEncodingASCII);

        GLFWglproc symbol = CFBundleGetFunctionPointerForName(_glfw.nsgl.framework,
                                                              symbolName);

        CFRelease(symbolName);

        return symbol;
    }
=#
    tmp = "_"*glFuncName
    if ccall(:NSIsSymbolNameDefined, Cint, (Ptr{Uint8},), tmp) == 0
        return convert(Ptr{Void}, 0)
    else
        symbol = ccall(:NSLookupAndBindSymbol, Ptr{Void}, (Ptr{Uint8},), tmp)
        return ccall(:NSAddressOfSymbol, Ptr{Void}, (Ptr{Void},), symbol)
    end
end

function wglGetProcAddress(glFuncName::ASCIIString)
    ccall((:wglGetProcAddress, "opengl32"), Ptr{Void}, (Ptr{Uint8},), glFuncName)
end


function getprocaddress(glFuncName::ASCIIString)
    @linux? ( glXGetProcAddress(glFuncName)
        :
        @windows? (wglGetProcAddress(glFuncName)
            :
            @osx? (NSGetProcAddress(glFuncName)
                :error("platform not supported")
            )
        )
    )
end

# Test, if an opengl function is available.
# Sadly, this doesn't work for Linux, as glxGetProcAddress 
# always returns a non null function pointer, as the function pointers are not depending on an active context.
#

function isavailable(name::Symbol)
    ptr = ModernGL.getprocaddress(ascii(string(name)))
    return isavailable(ptr)
end
function isavailable(ptr::Ptr{Void})
    return !(
        ptr == C_NULL || 
        ptr == convert(Ptr{Void}, -1) || 
        ptr == convert(Ptr{Void},  1) || 
        ptr == convert(Ptr{Void},  2) || 
        ptr == convert(Ptr{Void},  3))
end

macro getFuncPointer(func)
    z = gensym(func)
    @eval global $z = C_NULL
    quote begin
        global $z
        if $z::Ptr{Void} == C_NULL
            $z::Ptr{Void} = getprocaddress($(func))
            if !isavailable($z)
               error($(func), " not available for your driver, or no valid OpenGL context available")
            end
        end
        $z::Ptr{Void}
    end end
end

abstract Enum
macro GenEnums(list)
    tmp = list.args
    enumName = tmp[2]
    splice!(tmp, 1:2)
    enumType = typeof(eval(tmp[4].args[1].args[2]))
    enumdict1 = Dict{enumType, Symbol}()
    for elem in tmp
        if elem.head == :const
            enumdict1[eval(elem.args[1].args[2])] = elem.args[1].args[1]
        end
    end
    enumtype =  quote
        immutable $(enumName){T} <: Enum
            number::T
            name::Symbol
            enumdict = $enumdict1
            function $(enumName)(number::T)
                if !haskey(enumdict, number)
                    error("x is not a GLenum")
                end
                new(number, enumdict[number])
            end
        end
        $(enumName){T}(number::T) = $(enumName){T}(number)

    end
    esc(Expr(:block, enumtype, tmp..., Expr(:export, :($(enumName)))))
end


include("glTypes.jl")
include("glFunctions.jl")
include("glConstants.jl")

end # module
