<#
    .SYNOPSIS
    Windows New Menu Editor (v1.0 - Silent Edition)
    A modern WPF-based utility to manage, clean, and lock the Windows Context Menu "New" items. Code base switched Python to PowerShell.

    .DESCRIPTION
    Key Features:
    - Modern UI: Built with PowerShell & WPF, fully theme-aware (Light/Dark mode).
    - Silent Operation: Actions (Delete/Block) are executed instantly without nagging confirmation dialogs.
    - Persistence Lock: "Block" feature sets ACL Deny permissions to prevent unwanted apps from recreating entries.
    - Safety: Filters specifically for "ShellNew" entries in HKCU and HKLM.

    .AUTHOR
    @osmanonurkoc

    .LICENSE
    MIT License
#>

# =============================================================================
# 1. INITIALIZATION & API IMPORTS
# =============================================================================

# Define Win32 API for Dark Mode Title Bar support
$definition = @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
    [DllImport("dwmapi.dll", PreserveSig = true)]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);
}
"@
Add-Type -TypeDefinition $definition -Language CSharp
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# =============================================================================
# 2. PRIVILEGE CHECK
# =============================================================================
# The script requires Administrator privileges to modify HKLM keys and Registry ACLs.
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Path)`""
    Exit
}

# =============================================================================
# 3. THEME DETECTION ENGINE
# =============================================================================
# Detects Windows System Theme (Light/Dark) and sets the color palette accordingly.
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$isLightMode = 1
try {
    $val = Get-ItemProperty -Path $regPath -Name "AppsUseLightTheme" -ErrorAction SilentlyContinue
    if ($val -and $val.AppsUseLightTheme -eq 0) { $isLightMode = 0 }
} catch {}

if ($isLightMode -eq 0) {
    # Dark Mode Palette
    $c_Bg = "#202020"; $c_Fg = "#FFFFFF"; $c_Card = "#2D2D2D"; $c_Hover = "#3A3A3A"
    $c_Accent = "#0078D4"; $c_ScrollTrack = "#252525"; $c_ScrollThumb = "#606060"; $c_ScrollHover = "#909090"
    $c_DialogBg = "#2B2B2B"; $c_Border = "#404040"
    $dwm_Dark = 1
} else {
    # Light Mode Palette
    $c_Bg = "#F3F3F3"; $c_Fg = "#000000"; $c_Card = "#FFFFFF"; $c_Hover = "#E5E5E5"
    $c_Accent = "#0078D4"; $c_ScrollTrack = "#EFEFEF"; $c_ScrollThumb = "#BCBCBC"; $c_ScrollHover = "#707070"
    $c_DialogBg = "#FFFFFF"; $c_Border = "#D0D0D0"
    $dwm_Dark = 0
}

# =============================================================================
# 4. EMBEDDED RESOURCES
# =============================================================================
# App Icon (Base64 encoded)
$iconBase64 = "iVBORw0KGgoAAAANSUhEUgAAAIAAAACACAYAAADDPmHLAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAABHxSURBVHhe7Z17jFzVfcc/586d5z79wrSxwIBJnbZOoSKtpfIHapDahFnArSsIIc3uAiqRipoEWlUNKIpI/qiAJggkQMG7S3EaWlwZsuNAVEhoBZLToNQB1G6oSR1iCwPG3qd3Hvfe0z/ujHd9vDNzzp1778wu85FGs/s7d173fM/vnPM7L+jSpUuXLl26dOnSpUuXLl26fFgQqmFNMLw/A/Z2hPhtYBuCrcD5wGZgI9BbfdjLXjUNzFef3wWOIjkCHAY5hbSmmLhmftn1a4K1IYDhwhYEVyG4EvgDYLuSuWHgAFPAK0heRrovMXHdUfWi1cbqFcDI5BUgbgQ+ieAyNTkmppA8CzzDeP6gmrgaWF0CGC5sQ3Azgs8DW9XkNnMEyXeQ7uNMXHdETexUOl8Aw/ttRPJqBHcCV0Xg2qPgeaR8jPGhZ9SETqNzBeBn/M3AVxBsU5NXBZJDwIPIylNM7CqqyZ1AZwpgpHAz8NVVm/EqkimQ9zA+tE9NajedJYCRwk4E3wR2qklrAskhBLcxln9VTWoXnSGA4clBhLgPwa1q0ppE8ijSu4eJa0+oSXHTfgGMFPIIHgG2qElrnONIeUe7q4X2CWD4uQzCfQTBsJoUCQKElcBKWGBZCMs6K1l6HngenushPRfkWclR8jhe5Y52NRLbI4Dhye0IsR/BdjUpDKxEAiudwkolSaSTCNvGss16j9Jx8Cr+wy2VcUtlpOuql4XFFDDEWP6wmhA18Qtg5EAeIb9bjcWHgwA7kyGRzWBn0wjDzNbFcxzcxRLOYhG3WAIZqpsoIvkzxvMFNSFK4hXASOFuBPeq5qAkMmnsnix2LnuOS48a6Xk4p4s48wu4pbKaHBzJPYznv66aoyIeAQzvt7GS9wFfVJNMEUJg92RJDvQZu/Wo8MoVKgunqcwthOUVvoVX+WsmdjlqQthELwC/sfckgt1qkglCCJJ9PST7exGJhJrcEUjXpTw7H44QJPuQlc9F3TiMVgDDz2UQ3n6E/GM1yQS7J0d6sB9hd2bGq0jXpXRqBmdhUU0yQ/I8srIrShFEJwA/lv/dVkq+lbTJbFiHlU6pSasCt1SidHIGr1xRk/TxPcFnoqoOoms5Wcn7Ame+gFR/H7lfO2/VZj5AIp0md/4mUgN9IAKWNcHuavspEqLxqX5r/+9Usw7CTpA7byN2by74TeskhCCRSZNIp/BKJaQXqG2wk8tucjn0T/+hJrRK+HfY7+dPqmYd7Eya9Kb1sXfp4kJ6HsUTJ3EXS2qSHpKhsOME4QpguLANi9eBjJrUjGRfD+n1g6o5EgbTgj+/fAMfPz8LEl579zT//Pop3l3w1EsjoXxqhvJsoPml8yA/wdjQlJoQlPAE4Hf3/itIeDc12O/Xk5EjyV/ay6O7LmIgc3YMoeh4jDz9FoU352Opesozc5SnZ1WzDlN4lcvD6hmE52uF+1CQzE+vG4gt86/emuXJG7adk/kAGdviyRu2cfVFWeIYCUoN9JFeN6CaddiOlXxENQYlHAGMFHYHGctPrxsg2R/ekEBD3Ap//6kLsK36pdu2BA9ccyG2jGzQ5yyS/b1BRTDMSCGvGoPQugCGv7cRwUOquRmpwf74Mh/4+KYUH92UU83ncPGGLB/bYMfiBaiKIDXYr5qbI3iE4cmWG02tC0Ak7q2uutEm1d8bk9uvIj0u6Nfv8V7Qn0C0Gso1IDXQR7KvRzU3YwuWuF81mtKaAEYPXIGQt6vmRtjZNKlgbi84UoKn38IXnouMUQAA6fWDJDJp1dyMWxiZbGn+ZGsCkPLbqqkRlp0gvXG9ao4Jswyt31KIjsym9eYDXUJ8UzWZEFwAIwd2Gy3JEpDesK49QR5hmv3m14eBsCwym9abqm9ndRp9IILlxvBzGZBGEztS/X1BXFw4SLN72o7Mr5FIp0j1GTaOBV9leP+5fVsNgglAeDea9PkTqWS8jb4WMRFLFKTWDWAljfJzG5YdyAsEEwDyr1RLI1LrB2OJrtWljR8dlPSGdaqpCeIrQbyAuQBGDlxvUvcne3Ik2j2kG8Cnt1sziXQKuyermhuxDWFfrRqbYS4Ag26fEILUugBBjg4ggGZCJz04YOY5hbhTNTXDTADD398K/JFqrkeyr8e8W9PlDMJOmAaIrmJ00mhBrZkAhNSO9wshYg31NsKgDHUcqf5eEy9gI4VRY9BUAJ9VTfWwe3MdU/qloUs3uTZqRCJB0qQt4O+eoo2+AEYKO022ZUn2GrmuyNEuQx1I0qwLvdXfP0kPfQHA9aqhHonqurzVSqeJxbJtsyCaEDeqpnroC0BwnWqqR7f0h49hl/CTqqEeegIYntxS3XuvKUIIEjnjKYGREqRO7zTR2LmsyZe6jNHvae23oCcAIa5STfVIZNLtGfAJEdNGYxwIy8LOmBQsSyvP9HLK34FTi0TW5Et2JvoFLV4MPatWnukJwN9+VQs7a9BY6WKEUUNQM8+aC2D4QK9u/W8lEpFtztAqpi69E72AZdsmsZXt/qbZjWkuAOFpb7zcyev4TDLUF4vJK+LDYGDNxrKbFtzmAkA0fZMaBl+uoxGANPYZ8WAUX/G3y29IcwEY7NZpOImhSwCMCplsnnfNBWAQ/rWSBursYDqz7PsYbpLRNO+aV3SjhRe0IktC0HvBr6vWpthC8rFNGS4cNFC2KZ7HJ85P8OU/vFhNWZF/+OEv+MlxFwLFM/wKpBlvT5d57d1FEOafMf/2MZ2PAPgBY/mGu7PoCOAN4LdUs4qwE/R8xGB9iJRcfUkPD3z6Ai5e37SxuiZ58/1F/vYHv+Lf3lowGfJl4dhxpKO1fO0QY/nLVeNydOSntYrDskxck+RPf7OXp2+69EOb+QAf3ZTlX266lPylOYRmkQY/KqjJRtWgovNOemORDRZdqmzOwKO7Lmm4UPPDgm0JHv2TS+i3XQ137GMggKYzcnTeScsDaH8p6XHDjkEytub1HwIGMjafv3wDUuotX9O+1yEJIFw8jx2bjYY2PxTs2Jw1Wr+oSdN+efwCwIOY1t+vKqTnP2JGRwAh708neP1YoK1R1jSvH5sx6gmEhY4AFlTDSkhd9yUsJg6+zcxCwJ2y1iClistTP31HOyagfa/9U1AbovOJc6phRXT3v7MSzNLDX/zjQRxX+4esWRzXY3TsFd6rJLUbdwYCaLoVmc4nfqAaVsJzDWqKVI7CEZfdD/+IN49pvf2a5K3j0+x++Ic8+1YFkjmkZkdQ6hecph6g+SeOFp7XWg1kGgr2XCjN481/wI6NNhdu8PfsO4NWRFU2+AnL0yS/d9FG7sz/rnLNyjxQ+Cn/+X8nGrx3iwjBLz9Y4H9Oeri59Yh0LxgE0gxCwS8ylm+4XrD5LxwtTIDeYoOej2w2mxAiJXgOOGVfENJfyC+l3x6qPSOXfq+obvYgWCaQZRdJlsRTa1NJzyN/aY6nbv396gsac+PjP6bwvwtgJc66QWdL6lzDmTZczV59Xv47oJpm2WAn/WfNuh9AOi4Lx46r5no8wVi+4ZlMOp+sfQ6uVzGoBqhmXCIJ6R7I9kNuAJEdQOT64cxzP+T6EbkBRG7At2f9dHL+a8j2Vf/3XyOy/UvvkR1AZPoQtv50KmGn/ffI+p/nP87+3/+e/rO17O/a9/W//9m/h1z1O2cHEOkeSKSMMh/AqxjtPN4075p/ukT7ICO3lW3Rq/iFpFaUxLLHcpanL3+u/b30Gt8jqK/XQX2N+v8StYK99N2XPvvs37P0d+01ppgVMtk075oLAPmGaqlHS/vidxBBMycODM8narqncHMBSHtKNxjkmX25+DD0AGZXx4tb1r7HDp4VggAmPlXUURKA57pIR0sr8RLznn9R4TmO7jwAgJ8zcU0ocQCAV1RDPZyge+F3aYpbNLq3L6uGldAVgNabAbiLoexiHjprwQc4pw3urdDLM10BvKQa6uEUSyahylgQCKN6vRPFIj3PzANIVyvP9AQwlj8KHFLNKyKlmVJjwSxLTcQSF85i0aQtM8XYdUdV40roCcDnRdVQD2fhtGpqK9q3rYrp9XHgzGkNytZ4VjXUQ18AUj6lmurhFkt4ndgb0KTTPIBXrpj1/wXPqKZ66AtgfOhVndBijcqM3ihyHAjDUm1ybRxUzDzqEfbkD6rGeugLAEDyhGqqh7OwaDJsGSmmGdpJHkC6nn8WsT7fUQ2NMBOAkHt1o4JSSiqzneMFTDAVTJSUZ+dMGn+A+7hqaYSZAMaGDgP/rprrUZlbMIlcdVEIUPqfZ+w67WoaYwEASLTPqZFSUgp2Nl6oLI3P6WFybZSUTs0Yln75mGppRgABVF4A/SFiZ+G0WQs2AkxuYQ2z0FH4uKWyaXf6EGND2q3/GuYCmNjlgPyGam5E6YNpQyW3n7ZuECElpZNNp/MpyAdViw7mAgDwnL0mXsCrVChPr84GYTsoz86bzq2YwnO04zTLCSaAiV0O8DXV3Ijy3Hxb5wuYlGeTa8PGLZYpG8dQ5D1BzxIOJgCAsfxeQDvggJQsnjjZtoEikxrdtNEYFtLzKH1wyrS6PMTY0D7VqEtwAQBIvqSaGiEdl9L7p1RzR2KUBSFRPHHKPIQu5G2qyYTWBDCePwjsUc2NcIpFSidnVHMM6JfpdmR++dRMkLkUj7Fn6FXVaEJrAgDw5F2A1tBjjcrcfIB6LjhCCH55Uj+g8vbJReN5hK1QnpmjPNt09pbKcYR3t2o0pXUBTAxNI/mCam5GeXqWivmPDoRE8N/vl/nFe82DUm++M81r75428hitUJmdpxwoWCbvYM+1J1SrKa0LAGA8XwD9gaIapVMz8YhACFw7w5efPtRwQarjevzNv/4MkepBxOABKrPzfrTPnD2tNPyWE44AALzE7bqzh5dTOjUTT3Vgp3jxbZdb9rxMsXLu+MTMQpGbH/kRL/zKBTsVeTugPDMXNPOn8Cp/qRqDEq7MRya3I8RPdPamUUn190V/xqDnIhdnOY9Zbrh8M7+zZRAEvHZ0mokfH2UutQGR6UcaLNQMQunkDJW5QJ6viJQ7GB/SDsI1I1wBAIwcyCPkpGrWwc5kSG+K+IRx6YFTRpZP+4tS8b2DSOXANl+rZ4L0PIrvn8ItGrf2fSRD1eo2NMIXAMBo4W7A6HTxGpZtk96wjkQmwp1D8QNTSx0+EXmr3y2VKZ442crw+D2M5b+uGlslul89WvgWYHTI9BmEIDXQZ3poYmci5VI3zyzCt5wHGct/UTWGQXT+zqvchSRYS1VKytOzLB5/v+1Dya3glsqcfuc9v5EbNPMF+/Aqd6nmsIi2eA0/l8Hy9oNsuGFxM5I9OVLrBhCJ6PQaJtJxKU3Pmo7nr8TzeJVdQQd6dIhWAFRFINwnEexWk0wQQpDs6yHZ39exQpCuR3l2zp/GFbTE1xDsw618LsrMJxYBAAzvt7GS9wduEyxDCIHd20OyN2d2ekaEeI5LZWbOn77dasb7PIhXuas67B4p8QigRgu9g5VIpFMk+3pIZDPRdh1XQHoezumiP+XNZM1ecyJp7dcjXgFwJk7wNBDaPvFCCBKZNIlcBjuTNtuoygDpODjFEu7pIk6xFFZprzGP5DNh9/ObEb8AAEYmtyHEpO5xdKZYdgIrlfIPsU7aWMmk6VErZzZjcEtlvHIFr1TGcwP34ZsxhZS7GB8yDqW3SnsEQK2H4D4M3KImRYIQiITlH2xhiXOqDOl54El/lxPPC7t0N+IJvMrtUTf26tE+AdQYKexG8BBgcN7MmuAo8AXG4nX5KvG2nFZiPL8P4e0AjBc1rGL2YMkd7c58OsIDLGekcAWCbwOXqUlrhIPgfYmxa/Un00ZMZwmgxuiB3SDvjaqR2AYOA1+rzqTuKDpTAJxpJN5YDR6tVo9wGOQ38Jy9cQR1gtC5AljO6IHrQd6utWt5+3H8FdTyfjznhU7N+BqrQwA1Rr+/FeStID+rcyxqzBwB+QSwt7qMflWwugSwnNHCTuD66uM31OSY+BnwAsinGGttfn67WL0CWM7o5BbgKhBXAldWBRF2PNgBfl7dNPNl4KXq9nmrmrUhAJXbDvTietv9XoTYVq0utlSDTYPVSavLD8R0qodjzYM8AeI4cLzq1g8Db5Bypni0PdG6Ll26dOnSpUuXLl26dOnSpUuXMPh/Mb+dvsP7lf4AAAAASUVORK5CYII="

# =============================================================================
# 5. XAML UI DEFINITION (WPF)
# =============================================================================
[xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="New Menu Editor" Height="760" Width="450"
        WindowStartupLocation="CenterScreen" ResizeMode="CanMinimize"
        Background="$c_Bg" FontFamily="Segoe UI Variable Display">

    <Window.Resources>
        <Style x:Key="ModernScrollBar" TargetType="{x:Type ScrollBar}">
            <Setter Property="Stylus.IsFlicksEnabled" Value="false"/>
            <Setter Property="Foreground" Value="$c_ScrollThumb"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="Width" Value="8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollBar}">
                        <Grid x:Name="GridRoot" Width="8" Background="Transparent">
                            <Track x:Name="PART_Track" IsDirectionReversed="true" Focusable="false">
                                <Track.Thumb><Thumb x:Name="Thumb" Background="{TemplateBinding Foreground}" Style="{DynamicResource ScrollThumbs}"/></Track.Thumb>
                            </Track>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style x:Key="ScrollThumbs" TargetType="{x:Type Thumb}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type Thumb}">
                        <Grid x:Name="Grid">
                            <Border x:Name="Rectangle1" CornerRadius="4" Background="{TemplateBinding Background}"/>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="Rectangle1" Property="Background" Value="$c_ScrollHover"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
        <Style TargetType="{x:Type ScrollViewer}">
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ScrollViewer}">
                        <Grid Background="{TemplateBinding Background}">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <ScrollContentPresenter Grid.Column="0"/>
                            <ScrollBar x:Name="PART_VerticalScrollBar" Grid.Column="1" Value="{TemplateBinding VerticalOffset}" Maximum="{TemplateBinding ScrollableHeight}" ViewportSize="{TemplateBinding ViewportHeight}" Visibility="{TemplateBinding ComputedVerticalScrollBarVisibility}" Style="{StaticResource ModernScrollBar}"/>
                        </Grid>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style x:Key="ToggleSwitchStyle" TargetType="CheckBox">
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="CheckBox">
                        <Grid Background="Transparent" Height="30">
                            <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
                            <ContentPresenter Grid.Column="0" VerticalAlignment="Center" Content="{TemplateBinding Content}"/>
                            <Border x:Name="Track" Grid.Column="1" Width="44" Height="22" CornerRadius="11" Background="#666666" Margin="10,0,0,0">
                                <Ellipse x:Name="Thumb" Width="16" Height="16" Fill="White" HorizontalAlignment="Left" Margin="3,0,0,0">
                                    <Ellipse.Effect><DropShadowEffect ShadowDepth="1" BlurRadius="2" Opacity="0.3"/></Ellipse.Effect>
                                </Ellipse>
                            </Border>
                        </Grid>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsChecked" Value="True">
                                <Setter TargetName="Track" Property="Background" Value="$c_Accent"/>
                                <Setter TargetName="Thumb" Property="HorizontalAlignment" Value="Right"/>
                                <Setter TargetName="Thumb" Property="Margin" Value="0,0,3,0"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="{x:Type ContextMenu}">
            <Setter Property="SnapsToDevicePixels" Value="True" />
            <Setter Property="HasDropShadow" Value="True" />
            <Setter Property="Background" Value="$c_Card" />
            <Setter Property="Foreground" Value="$c_Fg" />
            <Setter Property="BorderThickness" Value="0" />
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type ContextMenu}">
                        <Border x:Name="Border" Background="$c_Card" BorderThickness="1" BorderBrush="$c_Border" CornerRadius="8" Padding="4">
                            <Border.Effect><DropShadowEffect BlurRadius="12" Color="Black" Opacity="0.3" ShadowDepth="4"/></Border.Effect>
                            <StackPanel IsItemsHost="True" KeyboardNavigation.DirectionalNavigation="Cycle" />
                        </Border>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="{x:Type MenuItem}">
            <Setter Property="Foreground" Value="$c_Fg"/>
            <Setter Property="FontSize" Value="13"/>
            <Setter Property="Background" Value="Transparent"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="{x:Type MenuItem}">
                        <Border x:Name="Border" Background="{TemplateBinding Background}" CornerRadius="4" Padding="{TemplateBinding Padding}">
                            <ContentPresenter Content="{TemplateBinding Header}" VerticalAlignment="Center" HorizontalAlignment="Left"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsHighlighted" Value="True">
                                <Setter TargetName="Border" Property="Background" Value="$c_Hover"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>

        <Style TargetType="Button">
            <Setter Property="Height" Value="40"/>
            <Setter Property="Background" Value="$c_Card"/>
            <Setter Property="Foreground" Value="$c_Fg"/>
            <Setter Property="BorderThickness" Value="0"/>
            <Setter Property="FontSize" Value="14"/>
            <Setter Property="FontWeight" Value="SemiBold"/>
            <Setter Property="Cursor" Value="Hand"/>
            <Setter Property="Template">
                <Setter.Value>
                    <ControlTemplate TargetType="Button">
                        <Border x:Name="border" Background="{TemplateBinding Background}" CornerRadius="6">
                            <ContentPresenter HorizontalAlignment="Center" VerticalAlignment="Center"/>
                        </Border>
                        <ControlTemplate.Triggers>
                            <Trigger Property="IsMouseOver" Value="True">
                                <Setter TargetName="border" Property="Background" Value="$c_Hover"/>
                            </Trigger>
                        </ControlTemplate.Triggers>
                    </ControlTemplate>
                </Setter.Value>
            </Setter>
        </Style>
    </Window.Resources>

    <Grid Margin="20,15,20,20">
        <Grid.RowDefinitions><RowDefinition Height="Auto"/><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>

        <Border Name="HeaderArea" Grid.Row="0" Background="Transparent" Margin="0,0,0,20" Cursor="Hand">
            <StackPanel HorizontalAlignment="Center">
                <Image Name="ImgLogo" Width="72" Height="72" Margin="0,0,0,10" RenderOptions.BitmapScalingMode="HighQuality"/>
                <TextBlock Text="New Menu Editor" FontSize="22" FontWeight="Bold" Foreground="$c_Fg" HorizontalAlignment="Center"/>
                <TextBlock Text="@osmanonurkoc" FontSize="14" Foreground="$c_Accent" HorizontalAlignment="Center" Margin="0,4,0,0" Opacity="0.9"/>
            </StackPanel>
        </Border>

        <Border Grid.Row="1" Background="$c_Card" CornerRadius="10" Padding="2">
            <Border.Effect><DropShadowEffect Color="Black" BlurRadius="10" Opacity="0.1" ShadowDepth="2"/></Border.Effect>
            <ScrollViewer VerticalScrollBarVisibility="Auto" Margin="2">
                <StackPanel Name="ListPanel" Margin="5"/>
            </ScrollViewer>
        </Border>

        <Grid Grid.Row="2" Margin="0,20,0,0">
            <Grid.ColumnDefinitions><ColumnDefinition Width="2*"/><ColumnDefinition Width="Auto"/><ColumnDefinition Width="Auto"/></Grid.ColumnDefinitions>
            <Button Name="BtnAdd" Grid.Column="0" Content="+ Add Template File" Background="$c_Accent" Foreground="White"/>
            <Button Name="BtnRestart" Grid.Column="1" ToolTip="Restart Explorer" Margin="10,0,0,0" Width="45">
                 <TextBlock Text="&#xE72C;" FontFamily="Segoe MDL2 Assets" FontSize="18"/>
            </Button>
            <Button Name="BtnFolder" Grid.Column="2" ToolTip="Open Templates Folder" Margin="10,0,0,0" Width="45">
                <TextBlock Text="&#xE8B7;" FontFamily="Segoe MDL2 Assets" FontSize="18"/>
            </Button>
        </Grid>
    </Grid>
</Window>
"@

# =============================================================================
# 6. LOAD XAML & BIND EVENTS
# =============================================================================
$reader = (New-Object System.Xml.XmlNodeReader $xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$ImgLogo = $window.FindName("ImgLogo")
$HeaderArea = $window.FindName("HeaderArea")
$ListPanel = $window.FindName("ListPanel")
$BtnAdd = $window.FindName("BtnAdd")
$BtnRestart = $window.FindName("BtnRestart")
$BtnFolder = $window.FindName("BtnFolder")

# Load Icon
if ($iconBase64 -ne "") {
    try {
        $bytes = [Convert]::FromBase64String($iconBase64)
        $mem = New-Object System.IO.MemoryStream($bytes, 0, $bytes.Length)
        $bmp = New-Object System.Windows.Media.Imaging.BitmapImage
        $bmp.BeginInit(); $bmp.StreamSource = $mem; $bmp.EndInit()
        $ImgLogo.Source = $bmp
    } catch {}
}

$HeaderArea.Add_MouseDown({ Start-Process "https://www.osmanonurkoc.com" })
# =============================================================================
# 7. REGISTRY SCANNER (CORE LOGIC) - WITH MRTCACHE EXCEPTION
# =============================================================================
function Get-RegistryItems-Fast {
    $items = @()
    $HKCU = [Microsoft.Win32.Registry]::CurrentUser
    $HKLM = [Microsoft.Win32.Registry]::LocalMachine

    # --- PART 1: STANDARD SCAN (Classic & Office) ---
    $targets = @(
        @{ Root=$HKCU; OtherRoot=$HKLM; Name="HKCU"; Path="Software\Classes"; PSDrive="HKCU:"; OtherPSDrive="HKLM:" },
        @{ Root=$HKLM; OtherRoot=$HKCU; Name="HKLM"; Path="Software\Classes"; PSDrive="HKLM:"; OtherPSDrive="HKCU:" }
    )

    foreach ($t in $targets) {
        try {
            $classesKey = $t.Root.OpenSubKey($t.Path)
            if ($classesKey -eq $null) { continue }
            $subKeys = $classesKey.GetSubKeyNames()
            foreach ($keyName in $subKeys) {
                if (-not $keyName.StartsWith(".")) { continue }
                try {
                    $extKey = $classesKey.OpenSubKey($keyName)
                    if ($extKey) {
                        # Scenario A: Direct ShellNew
                        $sn = $extKey.OpenSubKey("ShellNew");
                        if ($sn) { $items += [PSCustomObject]@{ Ext=$keyName; Hive=$t.Name; Type="Ext"; Path="$($t.PSDrive)\Software\Classes\$keyName\ShellNew"; Active=$true }; $sn.Close() }
                        $snd = $extKey.OpenSubKey("_ShellNew_Disabled");
                        if ($snd) { $items += [PSCustomObject]@{ Ext=$keyName; Hive=$t.Name; Type="Ext"; Path="$($t.PSDrive)\Software\Classes\$keyName\_ShellNew_Disabled"; Active=$false }; $snd.Close() }

                        # Scenario B: ProgID Redirect
                        $progID = $extKey.GetValue("")
                        if ($progID) {
                            $progKey = $classesKey.OpenSubKey($progID); $foundHiveStr = $t.PSDrive; $foundHiveName = $t.Name
                            if ($progKey -eq $null) {
                                $otherClasses = $t.OtherRoot.OpenSubKey("Software\Classes")
                                if ($otherClasses) { $progKey = $otherClasses.OpenSubKey($progID); if($progKey){$foundHiveStr=$t.OtherPSDrive; $foundHiveName=$t.OtherPSDrive.Replace(":","")}; $otherClasses.Close() }
                            }
                            if ($progKey) {
                                $psn = $progKey.OpenSubKey("ShellNew"); if ($psn) { $items += [PSCustomObject]@{ Ext="$keyName ($progID)"; Hive=$foundHiveName; Type="ProgID"; Path="$foundHiveStr\Software\Classes\$progID\ShellNew"; Active=$true }; $psn.Close() }
                                $psnd = $progKey.OpenSubKey("_ShellNew_Disabled"); if ($psnd) { $items += [PSCustomObject]@{ Ext="$keyName ($progID)"; Hive=$foundHiveName; Type="ProgID"; Path="$foundHiveStr\Software\Classes\$progID\_ShellNew_Disabled"; Active=$false }; $psnd.Close() }
                                $progKey.Close()
                            }
                        }

                        # Scenario C: Nested Subkeys
                        $innerKeys = $extKey.GetSubKeyNames()
                        foreach ($innerName in $innerKeys) {
                            if ($innerName -match "^Shell" -or $innerName -match "^OpenWith" -or $innerName -eq "PersistentHandler") { continue }
                            $nestedKey = $extKey.OpenSubKey($innerName)
                            if ($nestedKey) {
                                $nsn = $nestedKey.OpenSubKey("ShellNew"); if ($nsn) { $items += [PSCustomObject]@{ Ext="$keyName ($innerName)"; Hive=$t.Name; Type="Nested"; Path="$($t.PSDrive)\Software\Classes\$keyName\$innerName\ShellNew"; Active=$true }; $nsn.Close() }
                                $nsnd = $nestedKey.OpenSubKey("_ShellNew_Disabled"); if ($nsnd) { $items += [PSCustomObject]@{ Ext="$keyName ($innerName)"; Hive=$t.Name; Type="Nested"; Path="$($t.PSDrive)\Software\Classes\$keyName\$innerName\_ShellNew_Disabled"; Active=$false }; $nsnd.Close() }
                                $nestedKey.Close()
                            }
                        }
                        $extKey.Close()
                    }
                } catch {}
            }
            $classesKey.Close()
        } catch {}
    }

    # --- PART 2: PAINT MRTCACHE EXCEPTION (Dynamic Search) ---
    # This applies the logic found in your "bmp.reg" file.
    # It dynamically searches for the Paint key within MrtCache.

    $mrtPath = "HKCU:\Software\Classes\Local Settings\MrtCache"
    if (Test-Path $mrtPath) {
        # Search recursively for packages containing "Microsoft.Paint"
        $paintKeys = Get-ChildItem -Path $mrtPath -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "Microsoft.Paint" }

        foreach ($key in $paintKeys) {
            # Read properties (Values) of this key
            $props = Get-ItemProperty -Path $key.PSPath -ErrorAction SilentlyContinue

            # Look for the specific property name containing "ShellNewDisplayName_Bmp"
            # Example: @{Microsoft.Paint_...?ms-resource://...ShellNewDisplayName_Bmp}
            foreach ($propName in $props.PSObject.Properties.Name) {
                if ($propName -match "ShellNewDisplayName_Bmp") {

                    $val = $props.$propName
                    $isActive = -not [string]::IsNullOrEmpty($val) # Active if not empty

                    # Add to list as "Exception" type.
                    # We store the "Value Name" in the Path field (separated by |)
                    # because we need it for the toggle logic later.
                    $items += [PSCustomObject]@{
                        Ext = ".bmp (Modern Paint)";
                        Hive = "MrtCache";
                        Type = "Exception";
                        Path = "$($key.PSPath)|$propName";
                        Active = $isActive
                    }
                }
            }
        }
    }

    return $items | Sort-Object Ext | Select-Object -Unique Ext, Hive, Type, Path, Active
}

# =============================================================================
# 8. PERMISSION BLOCKING LOGIC
# =============================================================================
# Locks a Registry Key by setting specific ACL Deny rules.
function Block-Key {
    param($TargetKeyPath)
    try {
        if (Test-Path $TargetKeyPath) { Remove-Item -Path $TargetKeyPath -Recurse -Force }
        New-Item -Path $TargetKeyPath -Force | Out-Null
        $acl = Get-Acl $TargetKeyPath
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule("Everyone", "FullControl", "Deny")
        $acl.SetAccessRule($rule)
        Set-Acl -Path $TargetKeyPath -AclObject $acl
        return $true
    } catch {
        return $false
    }
}

# =============================================================================
# 9. UI RENDER LOGIC
# =============================================================================
function Draw-List {
    $ListPanel.Children.Clear()
    $items = Get-RegistryItems-Fast

    foreach ($item in $items) {
        $grid = New-Object System.Windows.Controls.Grid
        $grid.Margin = "0,0,0,8"
        $grid.Background = "Transparent"
        $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::new(1, [System.Windows.GridUnitType]::Star); [void]$grid.ColumnDefinitions.Add($c1)
        $c2 = New-Object System.Windows.Controls.ColumnDefinition; $c2.Width = [System.Windows.GridLength]::Auto; [void]$grid.ColumnDefinitions.Add($c2)

        # --- Context Menu (Right Click) ---
        $ctxMenu = New-Object System.Windows.Controls.ContextMenu

        # Option 1: Delete Permanently
        $menuDelete = New-Object System.Windows.Controls.MenuItem
        $menuDelete.Header = "Delete Permanently"
        $menuDelete.Foreground = "#FF5555" # Soft Red
        $menuDelete.Tag = $item.Path
        $menuDelete.Add_Click({
            $pathToDelete = $this.Tag
            # Silent execution - No MessageBox
            try {
                # If it's a pipe-separated path (Exception), we only delete the value, not key
                if ($pathToDelete -match "\|") {
                    $parts = $pathToDelete -split "\|"
                    Remove-ItemProperty -Path $parts[0] -Name $parts[1] -Force -ErrorAction SilentlyContinue
                } else {
                    Remove-Item -Path $pathToDelete -Recurse -Force
                }
                Draw-List
            } catch {
                [System.Windows.Forms.MessageBox]::Show("Error: " + $_.Exception.Message)
            }
        })

        # Option 2: Block (Permissions)
        $menuBlock = New-Object System.Windows.Controls.MenuItem
        $menuBlock.Header = "Block (Prevent Recreation)"
        $menuBlock.Foreground = "#FFAA00" # Orange
        $menuBlock.Tag = $item.Path
        $menuBlock.ToolTip = "Locks the key permissions to stop apps from recreating this entry."
        $menuBlock.Add_Click({
            $pathToBlock = $this.Tag
            # For Exceptions, we block the parent key
            if ($pathToBlock -match "\|") { $pathToBlock = ($pathToBlock -split "\|")[0] }

            if (Block-Key $pathToBlock) {
                Draw-List
            } else {
                [System.Windows.Forms.MessageBox]::Show("Failed to set permissions. Try running as Administrator.")
            }
        })

        [void]$ctxMenu.Items.Add($menuDelete)
        [void]$ctxMenu.Items.Add($menuBlock)
        $grid.ContextMenu = $ctxMenu

        # --- List Item UI ---
        $spText = New-Object System.Windows.Controls.StackPanel
        [void]$grid.Children.Add($spText)

        $txtMain = New-Object System.Windows.Controls.TextBlock; $txtMain.Text = $item.Ext; $txtMain.Foreground = $c_Fg; $txtMain.FontSize = 15; $txtMain.FontWeight = "SemiBold"; [void]$spText.Children.Add($txtMain)

        $borderBadge = New-Object System.Windows.Controls.Border; $borderBadge.Background = "#20888888"; $borderBadge.CornerRadius = "4"; $borderBadge.Padding = "5,1"; $borderBadge.HorizontalAlignment = "Left"; $borderBadge.Margin = "0,3,0,0"
        $txtBadge = New-Object System.Windows.Controls.TextBlock; $txtBadge.Text = "$($item.Hive) • $($item.Type)"; $txtBadge.Foreground = $c_Fg; $txtBadge.Opacity = 0.5; $txtBadge.FontSize = 11; $borderBadge.Child = $txtBadge
        [void]$spText.Children.Add($borderBadge)

        # --- Toggle Switch ---
        $cb = New-Object System.Windows.Controls.CheckBox;
        $cb.Style = $window.Resources["ToggleSwitchStyle"];
        $cb.IsChecked = $item.Active;
        $cb.Tag = $item; # <--- CHANGED: Storing full object to check .Type
        $cb.Content = if($item.Active){"On"}else{"Off"};
        $cb.Foreground = $c_Fg; $cb.Opacity = 0.8; $cb.FontSize = 12

        $cb.Add_Click({
            $itm = $this.Tag
            $isOn = $this.IsChecked
            $this.Content = if($isOn){"On"}else{"Off"}

            if ($itm.Type -eq "Exception") {
                # --- SPECIAL CASE: MRTCACHE (Modern Apps) ---
                # Logic: Toggle the registry value instead of renaming folders.
                # Path format: "RegistryKeyPath|ValueName"
                $parts = $itm.Path -split "\|"
                $regKey = $parts[0]
                $valName = $parts[1]

                if ($isOn) {
                    # Enable: Set value to "Bitmap image"
                    Set-ItemProperty -Path $regKey -Name $valName -Value "Bitmap image" -Force
                } else {
                    # Disable: Clear the value ("")
                    Set-ItemProperty -Path $regKey -Name $valName -Value "" -Force
                }
            }
            else {
                # --- STANDARD CASE: CLASSIC SHELLNEW ---
                # Logic: Rename "ShellNew" folder to "_ShellNew_Disabled"
                $parent = Split-Path -Parent $itm.Path
                if ($isOn) {
                    # Enable
                    $target = "$parent\ShellNew"
                    if (-not (Test-Path $target)) {
                        Rename-Item -Path $itm.Path -NewName "ShellNew" -Force
                        $itm.Path = $target
                    }
                } else {
                    # Disable
                    $target = "$parent\_ShellNew_Disabled"
                    if (Test-Path $target) { Remove-Item $target -Recurse -Force }
                    try {
                        Rename-Item -Path $itm.Path -NewName "_ShellNew_Disabled" -Force
                        $itm.Path = $target
                    } catch {
                        Remove-Item -Path $itm.Path -Recurse -Force
                    }
                }
            }
        })
        [void]$grid.Children.Add($cb); [System.Windows.Controls.Grid]::SetColumn($cb, 1); [void]$ListPanel.Children.Add($grid)
    }
}

# =============================================================================
# 10. BUTTON ACTIONS
# =============================================================================
$BtnAdd.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Filter = "All Files (*.*)|*.*"
    if ($dlg.ShowDialog() -eq "OK") {
        $file = $dlg.FileName
        $ext = [System.IO.Path]::GetExtension($file).ToLower()
        $name = [System.IO.Path]::GetFileName($file)
        $friendlyName = [System.IO.Path]::GetFileNameWithoutExtension($file)

        $tplDir = [Environment]::GetFolderPath("Templates")
        if ([string]::IsNullOrEmpty($tplDir)) { $tplDir = "$env:APPDATA\Microsoft\Windows\Templates" }
        if (-not (Test-Path $tplDir)) { New-Item -ItemType Directory -Path $tplDir | Out-Null }
        Copy-Item -Path $file -Destination "$tplDir\$name" -Force

        # Auto-register the extension and ProgID for ShellNew
        $autoProgID = $ext.Substring(1) + "_auto_file"
        Start-Process "reg" -ArgumentList "add `"HKCR\$ext`" /ve /d `"$autoProgID`" /f" -Wait -WindowStyle Hidden
        Start-Process "reg" -ArgumentList "add `"HKCR\$autoProgID`" /ve /d `"$friendlyName`" /f" -Wait -WindowStyle Hidden
        Start-Process "reg" -ArgumentList "add `"HKCR\$ext\ShellNew`" /v `"FileName`" /d `"$name`" /f" -Wait -WindowStyle Hidden
        Start-Process "reg" -ArgumentList "delete `"HKCR\$ext\ShellNew`" /v NullFile /f" -Wait -WindowStyle Hidden

        Draw-List
    }
})

$BtnRestart.Add_Click({ Stop-Process -Name explorer -Force })
$BtnFolder.Add_Click({ $tplDir = [Environment]::GetFolderPath("Templates"); if ([string]::IsNullOrEmpty($tplDir)) { $tplDir = "$env:APPDATA\Microsoft\Windows\Templates" }; Invoke-Item $tplDir })

# =============================================================================
# 11. STARTUP
# =============================================================================
$window.Add_SourceInitialized({
    $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
    $darkMode = $dwm_Dark
    # Apply Dark Mode to Title Bar (DWM API)
    [Win32]::DwmSetWindowAttribute($hwnd, 20, [ref]$darkMode, 4) | Out-Null
})

Draw-List
$window.ShowDialog() | Out-Null
