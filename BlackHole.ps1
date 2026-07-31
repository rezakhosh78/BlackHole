param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Windows.Forms
Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class BlackHoleWinInet {
    [DllImport("wininet.dll", SetLastError = true)]
    public static extern bool InternetSetOption(IntPtr hInternet, int option, IntPtr buffer, int length);
}
'@

$AppRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$CoreRoot = Join-Path $AppRoot 'core'
$RuntimeRoot = Join-Path $AppRoot 'runtime'
$ProfilePath = Join-Path $AppRoot 'profiles\defaults.json'
$UserSettingsPath = Join-Path $RuntimeRoot 'user-settings.json'
$SavedWorkspacePath = Join-Path $RuntimeRoot 'saved-workspace.json'
$SessionStatePath = Join-Path $RuntimeRoot 'session-state.json'
Import-Module (Join-Path $AppRoot 'BlackHole.Core.psm1') -Force

$createdNew = $false
$script:InstanceMutex = New-Object System.Threading.Mutex($true, 'Local\BlackHole.Gui', [ref]$createdNew)
if (-not $createdNew) {
    [System.Windows.MessageBox]::Show(
        'Black Hole is already running.', 'Black Hole', 'OK', 'Information'
    ) | Out-Null
    exit
}

if (Test-Path $SessionStatePath) {
    try {
        & (Join-Path $AppRoot 'Stop-BlackHole.ps1') | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show(
            "A previous session was found but could not be cleaned up: $($_.Exception.Message)",
            'Black Hole', 'OK', 'Warning'
        ) | Out-Null
    }
}

[xml]$Xaml = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Black Hole - Adaptive Desync for Xray" Width="1180" Height="780"
        MinWidth="980" MinHeight="680" WindowStartupLocation="CenterScreen"
        Background="#03040A" Foreground="#EAF2FF" FlowDirection="LeftToRight"
        FontFamily="Segoe UI">
  <Window.Resources>
    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightBrushKey}" Color="#1B6D8A"/>
    <SolidColorBrush x:Key="{x:Static SystemColors.HighlightTextBrushKey}" Color="#FFFFFF"/>
    <Style TargetType="TextBox">
      <Setter Property="Background" Value="#CC090C18"/>
      <Setter Property="Foreground" Value="#EAF2FF"/>
      <Setter Property="BorderBrush" Value="#26314F"/>
      <Setter Property="CaretBrush" Value="#7AF7FF"/>
      <Setter Property="Padding" Value="8"/>
      <Setter Property="Margin" Value="0,4,0,9"/>
    </Style>
    <Style x:Key="DarkComboBoxItemStyle" TargetType="{x:Type ComboBoxItem}">
      <Setter Property="Background" Value="#090C18"/>
      <Setter Property="Foreground" Value="#EAF2FF"/>
      <Setter Property="Padding" Value="7"/>
      <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ComboBoxItem}">
            <Border x:Name="ItemBorder"
                    Background="{TemplateBinding Background}"
                    Padding="{TemplateBinding Padding}"
                    SnapsToDevicePixels="True">
              <ContentPresenter HorizontalAlignment="{TemplateBinding HorizontalContentAlignment}"
                                VerticalAlignment="Center"
                                TextElement.Foreground="{TemplateBinding Foreground}"/>
            </Border>
            <ControlTemplate.Triggers>
              <Trigger Property="IsHighlighted" Value="True">
                <Setter TargetName="ItemBorder" Property="Background" Value="#1B6D8A"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
              </Trigger>
              <Trigger Property="IsSelected" Value="True">
                <Setter TargetName="ItemBorder" Property="Background" Value="#B36B2C"/>
                <Setter Property="Foreground" Value="#FFFFFF"/>
                <Setter Property="FontWeight" Value="SemiBold"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#657493"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="{x:Type ComboBoxItem}" BasedOn="{StaticResource DarkComboBoxItemStyle}"/>
    <Style TargetType="{x:Type ComboBox}">
      <Setter Property="Background" Value="#CC090C18"/>
      <Setter Property="Foreground" Value="#EAF2FF"/>
      <Setter Property="BorderBrush" Value="#26314F"/>
      <Setter Property="BorderThickness" Value="1"/>
      <Setter Property="Padding" Value="8,6"/>
      <Setter Property="Margin" Value="0,4,0,9"/>
      <Setter Property="Cursor" Value="Hand"/>
      <Setter Property="ItemContainerStyle" Value="{StaticResource DarkComboBoxItemStyle}"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type ComboBox}">
            <Grid>
              <Border x:Name="ComboBorder"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="{TemplateBinding BorderThickness}"
                      CornerRadius="3"/>
              <ContentPresenter x:Name="SelectionContent"
                                Margin="{TemplateBinding Padding}"
                                VerticalAlignment="Center"
                                HorizontalAlignment="Left"
                                IsHitTestVisible="False"
                                Content="{TemplateBinding SelectionBoxItem}"
                                ContentTemplate="{TemplateBinding SelectionBoxItemTemplate}"
                                ContentStringFormat="{TemplateBinding SelectionBoxItemStringFormat}"
                                TextElement.Foreground="{TemplateBinding Foreground}"/>
              <TextBox x:Name="PART_EditableTextBox"
                       Style="{x:Null}"
                       Margin="{TemplateBinding Padding}"
                       Padding="0"
                       VerticalContentAlignment="Center"
                       HorizontalContentAlignment="Left"
                       Foreground="{TemplateBinding Foreground}"
                       Background="Transparent"
                       BorderThickness="0"
                       CaretBrush="#7AF7FF"
                       IsReadOnly="{TemplateBinding IsReadOnly}"
                       Visibility="Collapsed"
                       Text="{Binding Text, RelativeSource={RelativeSource TemplatedParent}, Mode=TwoWay, UpdateSourceTrigger=PropertyChanged}"/>
              <Path HorizontalAlignment="Right"
                    VerticalAlignment="Center"
                    Margin="0,0,12,0"
                    Fill="#FFC46B"
                    Data="M 0 0 L 8 0 L 4 5 Z"
                    IsHitTestVisible="False"/>
              <ToggleButton Focusable="False"
                            ClickMode="Press"
                            Width="36"
                            HorizontalAlignment="Right"
                            Background="Transparent"
                            BorderThickness="0"
                            IsChecked="{Binding IsDropDownOpen, Mode=TwoWay, RelativeSource={RelativeSource TemplatedParent}}">
                <ToggleButton.Template>
                  <ControlTemplate TargetType="{x:Type ToggleButton}">
                    <Border Background="Transparent"/>
                  </ControlTemplate>
                </ToggleButton.Template>
              </ToggleButton>
              <Popup x:Name="PART_Popup"
                     Placement="Bottom"
                     IsOpen="{TemplateBinding IsDropDownOpen}"
                     AllowsTransparency="True"
                     Focusable="False"
                     PopupAnimation="Fade">
                <Border Background="#090C18"
                        BorderBrush="#31406A"
                        BorderThickness="1"
                        CornerRadius="8"
                        MinWidth="{Binding ActualWidth, RelativeSource={RelativeSource TemplatedParent}}">
                  <ScrollViewer MaxHeight="320"
                                CanContentScroll="True"
                                Background="#090C18">
                    <ItemsPresenter/>
                  </ScrollViewer>
                </Border>
              </Popup>
            </Grid>
            <ControlTemplate.Triggers>
              <Trigger Property="IsKeyboardFocusWithin" Value="True">
                <Setter TargetName="ComboBorder" Property="BorderBrush" Value="#7AF7FF"/>
              </Trigger>
              <Trigger Property="IsEditable" Value="True">
                <Setter TargetName="SelectionContent" Property="Visibility" Value="Collapsed"/>
                <Setter TargetName="PART_EditableTextBox" Property="Visibility" Value="Visible"/>
              </Trigger>
              <Trigger Property="IsEnabled" Value="False">
                <Setter Property="Foreground" Value="#657493"/>
                <Setter TargetName="ComboBorder" Property="Background" Value="#060814"/>
              </Trigger>
            </ControlTemplate.Triggers>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="Button">
      <Setter Property="Background" Value="#14203B"/>
      <Setter Property="Foreground" Value="#F4F7FF"/>
      <Setter Property="BorderBrush" Value="#34476F"/>
      <Setter Property="Padding" Value="12,8"/>
      <Setter Property="Margin" Value="4"/>
      <Setter Property="Cursor" Value="Hand"/>
    </Style>
    <Style TargetType="CheckBox">
      <Setter Property="Margin" Value="0,6,0,8"/>
      <Setter Property="Foreground" Value="#EAF2FF"/>
    </Style>
    <Style TargetType="GroupBox">
      <Setter Property="Background" Value="#7310162A"/>
      <Setter Property="BorderBrush" Value="#9931446F"/>
      <Setter Property="Foreground" Value="#7AF7FF"/>
      <Setter Property="Padding" Value="10"/>
      <Setter Property="Margin" Value="0,0,0,12"/>
      <Setter Property="Template">
        <Setter.Value>
          <ControlTemplate TargetType="{x:Type GroupBox}">
            <Grid SnapsToDevicePixels="True">
              <Grid.RowDefinitions>
                <RowDefinition Height="Auto"/>
                <RowDefinition Height="*"/>
              </Grid.RowDefinitions>
              <Border Grid.Row="0"
                      HorizontalAlignment="Left"
                      Margin="12,0,0,-1"
                      Padding="8,2"
                      CornerRadius="9"
                      Background="#99060814"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="1">
                <ContentPresenter ContentSource="Header"
                                  RecognizesAccessKey="True"
                                  TextElement.Foreground="{TemplateBinding Foreground}"/>
              </Border>
              <Border Grid.Row="1"
                      CornerRadius="12"
                      Background="{TemplateBinding Background}"
                      BorderBrush="{TemplateBinding BorderBrush}"
                      BorderThickness="1"
                      Padding="{TemplateBinding Padding}">
                <ContentPresenter/>
              </Border>
            </Grid>
          </ControlTemplate>
        </Setter.Value>
      </Setter>
    </Style>
    <Style TargetType="TabItem">
      <Setter Property="Background" Value="#0B1020"/>
      <Setter Property="Foreground" Value="#A7B6D8"/>
      <Setter Property="Padding" Value="12,7"/>
      <Style.Triggers>
        <Trigger Property="IsSelected" Value="True">
          <Setter Property="Background" Value="#162545"/>
          <Setter Property="Foreground" Value="#7AF7FF"/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>

  <Grid ClipToBounds="True">
    <Grid.Background>
      <RadialGradientBrush Center="0.62,0.18" GradientOrigin="0.62,0.18" RadiusX="0.92" RadiusY="0.82">
        <GradientStop Color="#17203C" Offset="0"/>
        <GradientStop Color="#070A16" Offset="0.42"/>
        <GradientStop Color="#03040A" Offset="1"/>
      </RadialGradientBrush>
    </Grid.Background>
    <Grid.Triggers>
      <EventTrigger RoutedEvent="FrameworkElement.Loaded">
        <BeginStoryboard>
          <Storyboard>
            <DoubleAnimation Storyboard.TargetName="AccretionRingOuter"
                             Storyboard.TargetProperty="(UIElement.RenderTransform).(RotateTransform.Angle)"
                             From="-16" To="344" Duration="0:0:24" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="AccretionRingInner"
                             Storyboard.TargetProperty="(UIElement.RenderTransform).(RotateTransform.Angle)"
                             From="9" To="-351" Duration="0:0:16" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="PhotonRing"
                             Storyboard.TargetProperty="(UIElement.RenderTransform).(RotateTransform.Angle)"
                             From="-4" To="356" Duration="0:0:10" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="LensGlow"
                             Storyboard.TargetProperty="Opacity"
                             From="0.18" To="0.42" Duration="0:0:3.2" AutoReverse="True" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="StarA"
                             Storyboard.TargetProperty="Opacity"
                             From="0.28" To="0.88" Duration="0:0:2.4" AutoReverse="True" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="StarB"
                             Storyboard.TargetProperty="Opacity"
                             From="0.16" To="0.72" Duration="0:0:3.1" AutoReverse="True" RepeatBehavior="Forever"/>
            <DoubleAnimation Storyboard.TargetName="StarC"
                             Storyboard.TargetProperty="Opacity"
                             From="0.24" To="0.68" Duration="0:0:2.7" AutoReverse="True" RepeatBehavior="Forever"/>
          </Storyboard>
        </BeginStoryboard>
      </EventTrigger>
    </Grid.Triggers>
    <MediaElement x:Name="BlackHoleVideo"
                  LoadedBehavior="Manual"
                  UnloadedBehavior="Manual"
                  Stretch="UniformToFill"
                  Opacity="0.58"
                  IsHitTestVisible="False"/>
    <Rectangle IsHitTestVisible="False" Opacity="0.62">
      <Rectangle.Fill>
        <RadialGradientBrush Center="0.62,0.20" GradientOrigin="0.62,0.20" RadiusX="0.92" RadiusY="0.82">
          <GradientStop Color="#00000000" Offset="0"/>
          <GradientStop Color="#070A16AA" Offset="0.45"/>
          <GradientStop Color="#03040AF2" Offset="1"/>
        </RadialGradientBrush>
      </Rectangle.Fill>
    </Rectangle>
    <Canvas IsHitTestVisible="False" ClipToBounds="True">
      <Ellipse x:Name="LensGlow" Width="760" Height="300" Canvas.Right="-70" Canvas.Top="-56"
               Opacity="0.28">
        <Ellipse.Fill>
          <RadialGradientBrush GradientOrigin="0.52,0.47" Center="0.52,0.47" RadiusX="0.58" RadiusY="0.42">
            <GradientStop Color="#553D10" Offset="0"/>
            <GradientStop Color="#1D7C9A" Offset="0.42"/>
            <GradientStop Color="#00000000" Offset="1"/>
          </RadialGradientBrush>
        </Ellipse.Fill>
      </Ellipse>
      <Ellipse x:Name="AccretionRingOuter" Width="660" Height="178" Canvas.Right="20" Canvas.Top="22"
               StrokeThickness="4" Opacity="0.46" RenderTransformOrigin="0.5,0.5">
        <Ellipse.Stroke>
          <LinearGradientBrush StartPoint="0,0.5" EndPoint="1,0.5">
            <GradientStop Color="#00000000" Offset="0"/>
            <GradientStop Color="#F3A444" Offset="0.20"/>
            <GradientStop Color="#7AF7FF" Offset="0.52"/>
            <GradientStop Color="#00000000" Offset="1"/>
          </LinearGradientBrush>
        </Ellipse.Stroke>
        <Ellipse.RenderTransform>
          <RotateTransform Angle="-16"/>
        </Ellipse.RenderTransform>
      </Ellipse>
      <Ellipse x:Name="AccretionRingInner" Width="470" Height="112" Canvas.Right="116" Canvas.Top="56"
               Stroke="#FFC46B" StrokeThickness="3" Opacity="0.52" RenderTransformOrigin="0.5,0.5">
        <Ellipse.RenderTransform>
          <RotateTransform Angle="9"/>
        </Ellipse.RenderTransform>
      </Ellipse>
      <Ellipse x:Name="PhotonRing" Width="238" Height="70" Canvas.Right="236" Canvas.Top="75"
               Stroke="#7AF7FF" StrokeThickness="2" Opacity="0.72" RenderTransformOrigin="0.5,0.5">
        <Ellipse.RenderTransform>
          <RotateTransform Angle="-4"/>
        </Ellipse.RenderTransform>
      </Ellipse>
      <Ellipse Width="150" Height="150" Canvas.Right="280" Canvas.Top="35"
               Fill="#010208" Stroke="#E09A42" StrokeThickness="2" Opacity="0.88"/>
      <Ellipse Width="86" Height="86" Canvas.Right="312" Canvas.Top="67" Fill="#000000" Opacity="0.96"/>
      <Ellipse x:Name="StarA" Width="5" Height="5" Canvas.Left="110" Canvas.Top="74" Fill="#EAF2FF" Opacity="0.75"/>
      <Ellipse x:Name="StarB" Width="4" Height="4" Canvas.Left="530" Canvas.Top="46" Fill="#7AF7FF" Opacity="0.50"/>
      <Ellipse x:Name="StarC" Width="3" Height="3" Canvas.Right="120" Canvas.Top="250" Fill="#FFC46B" Opacity="0.60"/>
      <Ellipse Width="2" Height="2" Canvas.Left="250" Canvas.Top="210" Fill="#A7B6D8" Opacity="0.54"/>
      <Ellipse Width="2" Height="2" Canvas.Right="420" Canvas.Top="305" Fill="#EAF2FF" Opacity="0.38"/>
    </Canvas>
    <Grid Margin="18">
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto"/>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <Grid Grid.Row="0" Margin="0,0,0,14">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <StackPanel Grid.Column="0">
        <StackPanel Orientation="Horizontal">
          <Grid Width="58" Height="58" Margin="0,0,14,0">
            <Ellipse Width="54" Height="54" Fill="#02030A" Stroke="#E09A42" StrokeThickness="2"/>
            <Ellipse Width="58" Height="18" Stroke="#7AF7FF" StrokeThickness="2" Opacity="0.85"
                     RenderTransformOrigin="0.5,0.5">
              <Ellipse.RenderTransform>
                <RotateTransform Angle="-18"/>
              </Ellipse.RenderTransform>
            </Ellipse>
            <Ellipse Width="18" Height="18" Fill="#000000" HorizontalAlignment="Center" VerticalAlignment="Center"/>
          </Grid>
          <StackPanel VerticalAlignment="Center">
            <TextBlock Text="Black Hole" FontSize="31" FontWeight="Bold" Foreground="#7AF7FF"/>
            <TextBlock Text="Adaptive Desync lab for VLESS + WS/XHTTP + TLS + Cloudflare" Foreground="#A7B6D8"/>
          </StackPanel>
        </StackPanel>
      </StackPanel>
      <Border Grid.Column="1" CornerRadius="20" Background="#7A10172A" BorderBrush="#9931446F"
              BorderThickness="1" Padding="16,8" VerticalAlignment="Center">
        <StackPanel Orientation="Horizontal">
          <Ellipse x:Name="StatusDot" Width="10" Height="10" Fill="#EF6671" Margin="0,0,8,0"/>
          <TextBlock x:Name="StatusText" Text="Stopped" VerticalAlignment="Center"/>
        </StackPanel>
      </Border>
    </Grid>

    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="390"/>
        <ColumnDefinition Width="14"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>

      <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto">
        <StackPanel>
          <GroupBox Header="1) Xray configuration">
            <StackPanel>
              <TextBlock Text="Paste a vless:// link or a complete Xray JSON:"/>
              <TextBox x:Name="ConfigInput" Height="112" AcceptsReturn="True" TextWrapping="Wrap"
                       VerticalScrollBarVisibility="Auto" FlowDirection="LeftToRight"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="*"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Button x:Name="ImportButton" Grid.Column="0" Content="Validate and import"/>
                <Button x:Name="OpenJsonButton" Grid.Column="1" Content="Open JSON"/>
              </Grid>
            </StackPanel>
          </GroupBox>

          <GroupBox Header="2) Gray IP">
            <StackPanel>
              <TextBlock Text="Original server address"/>
              <TextBox x:Name="OriginalAddress" IsReadOnly="True" FlowDirection="LeftToRight"/>
              <TextBlock Text="New Gray IP (replaces only address)"/>
              <TextBox x:Name="GrayAddress" FlowDirection="LeftToRight" ToolTip="Example: 104.18.10.10"/>
              <Button x:Name="ApplyGrayButton" Content="Apply address and preview"/>
              <TextBlock Text="Host and SNI remain unchanged." Foreground="#84D4A4" FontSize="11"/>
            </StackPanel>
          </GroupBox>

          <GroupBox Header="3) Desync profile">
            <StackPanel>
              <ComboBox x:Name="ProfileCombo"/>
              <TextBlock x:Name="ProfileDescription" Foreground="#9BB0D8" TextWrapping="Wrap" Margin="0,0,0,8"/>
              <CheckBox x:Name="SystemProxyCheck" Content="Set Windows proxy to 127.0.0.1:1920 automatically" IsChecked="True"/>
            </StackPanel>
          </GroupBox>

          <Grid Margin="0,4,0,4">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="*"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>
            <Button x:Name="StartButton" Grid.Column="0" Content="Start connection" Background="#157A70" FontWeight="Bold"/>
            <Button x:Name="StopButton" Grid.Column="1" Content="Stop connection" Background="#7E3340" FontWeight="Bold"/>
          </Grid>
        </StackPanel>
      </ScrollViewer>

      <TabControl Grid.Column="2" Background="#73060814" BorderBrush="#9931446F">
        <TabItem Header="Status">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <StackPanel Margin="16">
              <TextBlock Text="Configuration details" FontSize="19" FontWeight="Bold" Foreground="#7AF7FF" Margin="0,0,0,12"/>
              <Grid>
                <Grid.ColumnDefinitions>
                  <ColumnDefinition Width="150"/>
                  <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Grid.RowDefinitions>
                  <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                  <RowDefinition Height="Auto"/><RowDefinition Height="Auto"/><RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Address" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="0" Grid.Column="1" x:Name="MetaAddress" FlowDirection="LeftToRight"/>
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Port" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="1" Grid.Column="1" x:Name="MetaPort" FlowDirection="LeftToRight"/>
                <TextBlock Grid.Row="2" Grid.Column="0" Text="SNI" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="2" Grid.Column="1" x:Name="MetaSni" FlowDirection="LeftToRight"/>
                <TextBlock Grid.Row="3" Grid.Column="0" Text="WebSocket Host" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="3" Grid.Column="1" x:Name="MetaHost" FlowDirection="LeftToRight"/>
                <TextBlock Grid.Row="4" Grid.Column="0" Text="Network" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="4" Grid.Column="1" x:Name="MetaNetwork" FlowDirection="LeftToRight"/>
                <TextBlock Grid.Row="5" Grid.Column="0" Text="Security" Foreground="#A7B6D8"/>
                <TextBlock Grid.Row="5" Grid.Column="1" x:Name="MetaSecurity" FlowDirection="LeftToRight"/>
              </Grid>
            </StackPanel>
          </ScrollViewer>
        </TabItem>

        <TabItem Header="Advanced settings">
          <ScrollViewer VerticalScrollBarVisibility="Auto">
            <Grid Margin="16">
              <Grid.ColumnDefinitions>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="18"/>
                <ColumnDefinition Width="*"/>
              </Grid.ColumnDefinitions>
              <StackPanel Grid.Column="0">
                <TextBlock Text="Split method"/>
                <ComboBox x:Name="SplitModeCombo">
                  <ComboBoxItem Content="multisplit" IsSelected="True"/>
                  <ComboBoxItem Content="multidisorder"/>
                </ComboBox>
                <TextBlock Text="Allowed: multisplit or multidisorder" Foreground="#7388B1"
                           FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock Text="Split positions"/>
                <ComboBox x:Name="SplitPositionsCombo" IsEditable="True" IsTextSearchEnabled="False"
                          Text="1,midsld" FlowDirection="LeftToRight"
                          ToolTip="Choose a preset or type a custom supported position list">
                  <ComboBoxItem Content="midsld"/>
                  <ComboBoxItem Content="1,midsld" IsSelected="True"/>
                  <ComboBoxItem Content="1,sniext+1,midsld"/>
                </ComboBox>
                <TextBlock Text="Presets: midsld | 1,midsld | 1,sniext+1,midsld; custom lists may be typed"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock Text="Method preventing Fake delivery to server"/>
                <ComboBox x:Name="FoolingCombo">
                  <ComboBoxItem Content="badseq" IsSelected="True"/>
                  <ComboBoxItem Content="ttl"/>
                  <ComboBoxItem Content="badsum"/>
                  <ComboBoxItem Content="md5sig"/>
                  <ComboBoxItem Content="none"/>
                </ComboBox>
                <TextBlock Text="Allowed: none, badseq, ttl, badsum or md5sig" Foreground="#7388B1"
                           FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock x:Name="BadSequenceLabel" Text="Bad Sequence Increment"/>
                <TextBox x:Name="BadSequence" Text="-10000" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: -2000000000 to -1; active only when Fooling = badseq"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock x:Name="FakeSniLabel" Text="Optional Fake SNI"/>
                <ComboBox x:Name="FakeSni" IsEditable="True" IsTextSearchEnabled="False"
                          Text="" FlowDirection="LeftToRight"
                          ToolTip="Empty = random SNI; choose a preset or type a valid hostname">
                  <ComboBoxItem Content=""/>
                  <ComboBoxItem Content="hcaptcha.com"/>
                  <ComboBoxItem Content="www.cloudflare.com"/>
                  <ComboBoxItem Content="speed.cloudflare.com"/>
                  <ComboBoxItem Content="www.microsoft.com"/>
                </ComboBox>
                <TextBlock Text="Empty = random SNI; presets are only for the Fake packet; real SNI/Host stay unchanged"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
              </StackPanel>
              <StackPanel Grid.Column="2">
                <TextBlock x:Name="AutoTtlDeltaLabel" Text="AutoTTL Delta"/>
                <TextBox x:Name="AutoTtlDelta" Text="2" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 10; active only when Fooling = ttl" Foreground="#7388B1"
                           FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock x:Name="AutoTtlMinLabel" Text="AutoTTL Min"/>
                <TextBox x:Name="AutoTtlMin" Text="3" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 255; must be less than or equal to AutoTTL Max"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock x:Name="AutoTtlMaxLabel" Text="AutoTTL Max"/>
                <TextBox x:Name="AutoTtlMax" Text="20" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 255; must be greater than or equal to AutoTTL Min"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock x:Name="RepeatsLabel" Text="Fake repeats"/>
                <TextBox x:Name="Repeats" Text="1" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 10; active only when Fake is enabled (Fooling is not none)"
                           TextWrapping="Wrap" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock Text="SOCKS Port"/>
                <TextBox x:Name="SocksPort" Text="1819" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 65535" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock Text="HTTP Port"/>
                <TextBox x:Name="HttpPort" Text="1920" FlowDirection="LeftToRight"/>
                <TextBlock Text="Range: 1 to 65535" Foreground="#7388B1" FontSize="10" Margin="0,-5,0,7"/>
                <TextBlock Text="Both listeners bind to 0.0.0.0" Foreground="#84D4A4" FontSize="11"/>
              </StackPanel>
            </Grid>
          </ScrollViewer>
        </TabItem>

        <TabItem Header="Config output">
          <Grid Margin="12">
            <Grid.RowDefinitions>
              <RowDefinition Height="*"/>
              <RowDefinition Height="Auto"/>
            </Grid.RowDefinitions>
            <TextBox x:Name="ConfigPreview" Grid.Row="0" IsReadOnly="True" AcceptsReturn="True"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                     FontFamily="Consolas" FontSize="12" FlowDirection="LeftToRight"/>
            <Grid Grid.Row="1">
              <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="*"/></Grid.ColumnDefinitions>
              <Button x:Name="SaveConfigButton" Grid.Column="0" Content="Save config.json"/>
              <Button x:Name="PreviewCommandButton" Grid.Column="1" Content="Preview Desync command"/>
            </Grid>
          </Grid>
        </TabItem>

        <TabItem Header="Log">
          <Grid Margin="12">
            <Grid.RowDefinitions><RowDefinition Height="*"/><RowDefinition Height="Auto"/></Grid.RowDefinitions>
            <TextBox x:Name="LogBox" Grid.Row="0" IsReadOnly="True" AcceptsReturn="True"
                     VerticalScrollBarVisibility="Auto" HorizontalScrollBarVisibility="Auto"
                     FontFamily="Consolas" FontSize="12" FlowDirection="LeftToRight"/>
            <Button x:Name="OpenLogsButton" Grid.Row="1" Content="Open log folder"/>
          </Grid>
        </TabItem>
      </TabControl>
    </Grid>

    <Grid Grid.Row="2" Margin="0,12,0,0">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>
      <TextBlock x:Name="FooterText" Grid.Column="0" Foreground="#7B8BAE"
                 Text="Administrator access is required for packet processing."/>
      <TextBlock Grid.Column="1" Text="Powered By ReZa Kh"
                 Foreground="#FFD36A" FontWeight="SemiBold"
                 HorizontalAlignment="Right" VerticalAlignment="Center"/>
    </Grid>
    </Grid>
  </Grid>
</Window>
'@

$reader = New-Object System.Xml.XmlNodeReader $Xaml
$Window = [Windows.Markup.XamlReader]::Load($reader)

$ControlNames = @(
    'BlackHoleVideo','StatusDot','StatusText','ConfigInput','ImportButton','OpenJsonButton',
    'OriginalAddress','GrayAddress','ApplyGrayButton','ProfileCombo','ProfileDescription',
    'SystemProxyCheck','StartButton','StopButton','MetaAddress','MetaPort',
    'MetaSni','MetaHost','MetaNetwork','MetaSecurity','SplitModeCombo','SplitPositionsCombo',
    'FoolingCombo','BadSequenceLabel','BadSequence','FakeSniLabel','FakeSni',
    'AutoTtlDeltaLabel','AutoTtlDelta','AutoTtlMinLabel','AutoTtlMin',
    'AutoTtlMaxLabel','AutoTtlMax','RepeatsLabel','Repeats','SocksPort','HttpPort',
    'ConfigPreview','SaveConfigButton',
    'PreviewCommandButton','LogBox','OpenLogsButton','FooterText'
)
foreach ($name in $ControlNames) {
    Set-Variable -Name $name -Value $Window.FindName($name) -Scope Script
}

$script:Config = $null
$script:OriginalServerAddress = ""
$script:XrayProcess = $null
$script:WinwsProcess = $null
$script:ProxyBackup = $null
$script:IsConnected = $false
$script:IsStopping = $false
$script:IsUiInitialized = $false
$script:LoadedUserSettings = $false
$script:AutoSaveTimer = $null
$script:Profiles = Get-DesyncProfiles

function Write-AppLog {
    param([string]$Message)
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $Message
    $LogBox.AppendText($line + [Environment]::NewLine)
    $LogBox.ScrollToEnd()
}

function Show-AppError {
    param([string]$Message)
    Write-AppLog "ERROR: $Message"
    [System.Windows.MessageBox]::Show(
        $Message, 'Black Hole', 'OK', 'Error'
    ) | Out-Null
}

function Start-BackgroundVideo {
    $videoPath = Join-Path $AppRoot 'assets\blackhole-loop.mp4'
    if (-not (Test-Path -LiteralPath $videoPath -PathType Leaf)) { return }
    try {
        $BlackHoleVideo.Source = [Uri]::new($videoPath)
        $BlackHoleVideo.Position = [TimeSpan]::Zero
        $BlackHoleVideo.Play()
    } catch {
        Write-AppLog "Background video unavailable; animated fallback remains active: $($_.Exception.Message)"
    }
}

function Set-AppStatus {
    param([bool]$Connected, [string]$Text)
    $script:IsConnected = $Connected
    $StatusText.Text = $Text
    $StatusDot.Fill = if ($Connected) { '#55D6A4' } else { '#EF6671' }
}

function Get-ComboText {
    param($ComboBox)
    if ($null -ne $ComboBox.SelectedItem -and
        $null -ne $ComboBox.SelectedItem.PSObject.Properties['Content']) {
        return [string]$ComboBox.SelectedItem.Content
    }
    return [string]$ComboBox.Text
}

function Select-ComboText {
    param($ComboBox, [string]$Text)
    foreach ($item in $ComboBox.Items) {
        $value = if ($null -ne $item.PSObject.Properties['Content']) {
            [string]$item.Content
        } else {
            [string]$item
        }
        if ($value -eq $Text) {
            $ComboBox.SelectedItem = $item
            if ($ComboBox.IsEditable) {
                $ComboBox.Text = $Text
            }
            return
        }
    }
    if ($ComboBox.IsEditable) {
        $ComboBox.SelectedItem = $null
        $ComboBox.Text = $Text
    }
}

function Test-ClickInsideComboToggle {
    param($OriginalSource)
    if ($null -eq $OriginalSource -or
        -not ($OriginalSource -is [System.Windows.DependencyObject])) {
        return $false
    }

    $node = [System.Windows.DependencyObject]$OriginalSource
    while ($null -ne $node) {
        if ($node -is [System.Windows.Controls.Primitives.ToggleButton]) {
            return $true
        }
        try {
            $node = [System.Windows.Media.VisualTreeHelper]::GetParent($node)
        } catch {
            return $false
        }
    }
    return $false
}

function Enable-ComboBoxFullClickDropdown {
    param($ComboBox)
    $ComboBox.StaysOpenOnEdit = $true
    $ComboBox.Add_PreviewMouseLeftButtonDown({
        param($sender, $eventArgs)
        if (Test-ClickInsideComboToggle -OriginalSource $eventArgs.OriginalSource) {
            return
        }
        if ($sender.IsEnabled -and -not $sender.IsDropDownOpen) {
            $sender.IsDropDownOpen = $true
        }
    })
}

function Get-ProfileKeyFromItem {
    param($Item)
    if ($null -eq $Item) { return '' }
    if ($null -ne $Item.PSObject.Properties['Tag'] -and
        -not [string]::IsNullOrWhiteSpace([string]$Item.Tag)) {
        return [string]$Item.Tag
    }
    if ($null -ne $Item.PSObject.Properties['Content']) {
        return [string]$Item.Content
    }
    return [string]$Item
}

function Get-SelectedProfileKey {
    return Get-ProfileKeyFromItem $ProfileCombo.SelectedItem
}

function Get-SelectedProfile {
    $key = Get-SelectedProfileKey
    if (-not $script:Profiles.Contains($key)) { throw "Select a Desync profile." }
    return $script:Profiles[$key]
}

function Update-SystemProxyLabel {
    $portText = $HttpPort.Text.Trim()
    if ([string]::IsNullOrWhiteSpace($portText)) { $portText = '1920' }
    $SystemProxyCheck.Content = "Set Windows proxy to 127.0.0.1:$portText automatically"
}

function Sync-CurrentConfigFromUi {
    if ($null -eq $script:Config) { return }
    $script:Config = Ensure-LocalInbounds -Config $script:Config `
        -SocksPort ([int]$SocksPort.Text) -HttpPort ([int]$HttpPort.Text)
    $script:Config = Disable-XrayMux -Config $script:Config
    Update-ConfigView
}

function Apply-ProfileToAdvancedSettings {
    param([Parameter(Mandatory)][string]$ProfileKey)
    if (-not $script:Profiles.Contains($ProfileKey)) {
        throw "Unknown Desync profile: $ProfileKey"
    }
    $profile = $script:Profiles[$ProfileKey]
    $values = $profile.Advanced
    if ($null -eq $values) { return }

    Select-ComboText -ComboBox $SplitModeCombo -Text ([string]$values.SplitMode)
    Select-ComboText -ComboBox $FoolingCombo -Text ([string]$values.Fooling)
    Select-ComboText -ComboBox $SplitPositionsCombo -Text ([string]$values.SplitPositions)
    $BadSequence.Text = [string]$values.BadSequence
    $AutoTtlDelta.Text = [string]$values.AutoTtlDelta
    $AutoTtlMin.Text = [string]$values.AutoTtlMin
    $AutoTtlMax.Text = [string]$values.AutoTtlMax
    $Repeats.Text = [string]$values.Repeats
    Select-ComboText -ComboBox $FakeSni -Text ([string]$values.FakeSni)
    Update-AdvancedDependencyState
}

function Set-AdvancedFieldState {
    param(
        [Parameter(Mandatory)]$Label,
        [Parameter(Mandatory)]$Control,
        [Parameter(Mandatory)][bool]$Enabled
    )
    $Label.IsEnabled = $Enabled
    $Control.IsEnabled = $Enabled
    $Label.Opacity = if ($Enabled) { 1.0 } else { 0.45 }
    $Control.Opacity = if ($Enabled) { 1.0 } else { 0.45 }
}

function Update-AdvancedDependencyState {
    $fooling = Get-ComboText $FoolingCombo
    $fakeEnabled = $fooling -ne 'none'
    Set-AdvancedFieldState -Label $BadSequenceLabel -Control $BadSequence `
        -Enabled ($fooling -eq 'badseq')
    Set-AdvancedFieldState -Label $AutoTtlDeltaLabel -Control $AutoTtlDelta `
        -Enabled ($fooling -eq 'ttl')
    Set-AdvancedFieldState -Label $AutoTtlMinLabel -Control $AutoTtlMin `
        -Enabled ($fooling -eq 'ttl')
    Set-AdvancedFieldState -Label $AutoTtlMaxLabel -Control $AutoTtlMax `
        -Enabled ($fooling -eq 'ttl')
    Set-AdvancedFieldState -Label $FakeSniLabel -Control $FakeSni `
        -Enabled $fakeEnabled
    Set-AdvancedFieldState -Label $RepeatsLabel -Control $Repeats `
        -Enabled $fakeEnabled
}

function Get-AdvancedSettingsSummary {
    $fooling = Get-ComboText $FoolingCombo
    $badSeqSummary = if ($fooling -eq 'badseq') { $BadSequence.Text.Trim() } else { 'inactive' }
    $autoTtlSummary = if ($fooling -eq 'ttl') {
        "$($AutoTtlDelta.Text.Trim()),$($AutoTtlMin.Text.Trim())-$($AutoTtlMax.Text.Trim())"
    } else { 'inactive' }
    $repeatsSummary = if ($fooling -ne 'none') { $Repeats.Text.Trim() } else { 'inactive' }
    $fakeSniSummary = if ($fooling -ne 'none') { $FakeSni.Text.Trim() } else { 'inactive' }
    return "split=$(Get-ComboText $SplitModeCombo); positions=$(Get-ComboText $SplitPositionsCombo); " +
        "fooling=$fooling; badseq=$badSeqSummary; autottl=$autoTtlSummary; " +
        "repeats=$repeatsSummary; fakeSni=$fakeSniSummary"
}

function Apply-SelectedProfileToAdvancedSettings {
    Apply-ProfileToAdvancedSettings -ProfileKey (Get-SelectedProfileKey)
}

function Update-ConfigView {
    if ($null -eq $script:Config) { return }
    $metadata = Get-ConfigMetadata $script:Config
    $MetaAddress.Text = $metadata.Address
    $MetaPort.Text = [string]$metadata.Port
    $MetaSni.Text = $metadata.Sni
    $MetaHost.Text = $metadata.Host
    $MetaNetwork.Text = $metadata.Network
    $MetaSecurity.Text = $metadata.Security
    $ConfigPreview.Text = $script:Config | ConvertTo-Json -Depth 100
}

function Import-CurrentConfig {
    $config = ConvertFrom-XrayInput -Text $ConfigInput.Text
    $config = Ensure-LocalInbounds -Config $config -SocksPort ([int]$SocksPort.Text) -HttpPort ([int]$HttpPort.Text)
    $config = Disable-XrayMux -Config $config
    $metadata = Get-ConfigMetadata $config
    $script:Config = $config
    $script:OriginalServerAddress = $metadata.Address
    $OriginalAddress.Text = $metadata.Address
    $GrayAddress.Text = $metadata.Address
    Update-ConfigView
    Write-AppLog "Config imported. Address=$($metadata.Address), SNI=$($metadata.Sni), Host=$($metadata.Host)"
    Request-AutoSave
}

function Apply-GrayIp {
    if ($null -eq $script:Config) { Import-CurrentConfig }
    $script:Config = Set-GrayAddress -Config $script:Config -Address $GrayAddress.Text
    Update-ConfigView
    Write-AppLog "Gray IP applied to VLESS address: $($GrayAddress.Text.Trim())"
    Request-AutoSave
    if ($script:IsConnected) {
        Write-AppLog 'The running connection still uses the previous address. Press Start to restart with this IP.'
    }
}

function Find-CoreFile {
    param([string]$Name)
    $file = Get-ChildItem -Path $CoreRoot -Filter $Name -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTimeUtc -Descending | Select-Object -First 1
    if ($null -eq $file) { return $null }
    return $file.FullName
}

function Get-DesyncArguments {
    param([string]$HostListPath, [string]$IpSetPath, [switch]$Preview)
    $profile = Get-SelectedProfile
    if (-not $profile.Enabled) { return @() }
    $luaLib = Find-CoreFile 'engine-lib.lua'
    $luaAnti = Find-CoreFile 'engine-antidpi.lua'
    if ($Preview) {
        if (-not $luaLib) { $luaLib = '<core>\desync\lua\engine-lib.lua' }
        if (-not $luaAnti) { $luaAnti = '<core>\desync\lua\engine-antidpi.lua' }
    } else {
        if (-not $luaLib -or -not $luaAnti) {
            throw "Desync core files were not found. Extract the complete ZIP again."
        }
    }
    $fooling = Get-ComboText $FoolingCombo
    $argumentParameters = @{
        Profile = $profile.Strategy
        HostListPath = $HostListPath
        IpSetPath = $IpSetPath
        LuaLibraryPath = $luaLib
        LuaAntiDpiPath = $luaAnti
        Port = [int](Get-ConfigMetadata $script:Config).Port
        SplitMode = (Get-ComboText $SplitModeCombo)
        SplitPositions = (Get-ComboText $SplitPositionsCombo)
        Fooling = $fooling
    }
    if ($fooling -eq 'badseq') {
        $argumentParameters.BadSequence = [int]$BadSequence.Text
    }
    if ($fooling -eq 'ttl') {
        $argumentParameters.AutoTtlDelta = [int]$AutoTtlDelta.Text
        $argumentParameters.AutoTtlMin = [int]$AutoTtlMin.Text
        $argumentParameters.AutoTtlMax = [int]$AutoTtlMax.Text
    }
    if ($fooling -ne 'none') {
        $argumentParameters.Repeats = [int]$Repeats.Text
        $argumentParameters.FakeSni = $FakeSni.Text.Trim()
    }
    return New-Winws2ArgumentList @argumentParameters
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $encoding)
}

function Read-Utf8Text {
    param([string]$Path)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    return [System.IO.File]::ReadAllText($Path, $encoding)
}

function Get-NativeProcessDetails {
    param(
        [Parameter(Mandatory)]$Process,
        [string[]]$LogPaths = @()
    )
    $parts = New-Object System.Collections.Generic.List[string]
    $parts.Add("Exit code: $($Process.ExitCode)")
    foreach ($path in $LogPaths) {
        if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -LiteralPath $path)) {
            $lines = @(Get-Content -LiteralPath $path -ErrorAction SilentlyContinue)
            if ($lines.Count -gt 0) {
                $parts.Add("")
                $parts.Add("[$([System.IO.Path]::GetFileName($path))]")
                foreach ($line in @($lines | Select-Object -Last 80)) {
                    $parts.Add([string]$line)
                }
            }
        }
    }
    if ($parts.Count -eq 1 -and $Process.ExitCode -eq -1073741515) {
        $parts.Add("Windows could not load a required runtime DLL (0xC0000135).")
    }
    return ($parts -join [Environment]::NewLine).Trim()
}

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-RegistryValueState {
    param([string]$Path, [string]$Name)
    $item = Get-ItemProperty -Path $Path -ErrorAction Stop
    $property = $item.PSObject.Properties[$Name]
    return [ordered]@{
        Exists = ($null -ne $property)
        Value = if ($null -ne $property) { $property.Value } else { $null }
    }
}

function Refresh-WindowsProxy {
    [void][BlackHoleWinInet]::InternetSetOption([IntPtr]::Zero, 39, [IntPtr]::Zero, 0)
    [void][BlackHoleWinInet]::InternetSetOption([IntPtr]::Zero, 37, [IntPtr]::Zero, 0)
}

function Enable-WindowsProxy {
    param([int]$Port)
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    $backup = [ordered]@{
        ProxyEnable = Get-RegistryValueState -Path $path -Name 'ProxyEnable'
        ProxyServer = Get-RegistryValueState -Path $path -Name 'ProxyServer'
        ProxyOverride = Get-RegistryValueState -Path $path -Name 'ProxyOverride'
    }
    Set-ItemProperty -Path $path -Name ProxyEnable -Type DWord -Value 1
    Set-ItemProperty -Path $path -Name ProxyServer -Type String -Value "127.0.0.1:$Port"
    Set-ItemProperty -Path $path -Name ProxyOverride -Type String -Value '<local>'
    Refresh-WindowsProxy
    return $backup
}

function Restore-WindowsProxy {
    if ($null -eq $script:ProxyBackup) { return }
    $path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
    foreach ($name in @('ProxyEnable','ProxyServer','ProxyOverride')) {
        $state = $script:ProxyBackup.$name
        if ([bool]$state.Exists) {
            $type = if ($name -eq 'ProxyEnable') { 'DWord' } else { 'String' }
            Set-ItemProperty -Path $path -Name $name -Type $type -Value $state.Value
        } else {
            Remove-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue
        }
    }
    Refresh-WindowsProxy
    $script:ProxyBackup = $null
}

function Save-SessionState {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
    $state = [ordered]@{
        xrayPid = if ($null -ne $script:XrayProcess) { $script:XrayProcess.Id } else { $null }
        winwsPid = if ($null -ne $script:WinwsProcess) { $script:WinwsProcess.Id } else { $null }
        proxyBackup = $script:ProxyBackup
        createdAt = (Get-Date).ToString('o')
    }
    Write-Utf8NoBom -Path $SessionStatePath -Content ($state | ConvertTo-Json -Depth 10)
}

function Remove-SensitiveRuntimeFiles {
    foreach ($name in @('active-config.json','active-hosts.txt','active-gray-ip.txt','session-state.json')) {
        Remove-Item -LiteralPath (Join-Path $RuntimeRoot $name) -Force -ErrorAction SilentlyContinue
    }
}

function Stop-BlackHole {
    if ($script:IsStopping) { return }
    $script:IsStopping = $true
    try {
        if ($null -ne $script:XrayProcess -and -not $script:XrayProcess.HasExited) {
            Stop-Process -Id $script:XrayProcess.Id -Force -ErrorAction SilentlyContinue
        }
        if ($null -ne $script:WinwsProcess -and -not $script:WinwsProcess.HasExited) {
            Stop-Process -Id $script:WinwsProcess.Id -Force -ErrorAction SilentlyContinue
        }
        Restore-WindowsProxy
    } finally {
        $script:XrayProcess = $null
        $script:WinwsProcess = $null
        Remove-SensitiveRuntimeFiles
        Set-AppStatus $false 'Stopped'
        Write-AppLog 'Connection stopped and previous Windows proxy settings restored.'
        $script:IsStopping = $false
    }
}

function Start-BlackHole {
    if (-not (Test-Administrator)) {
        throw "Run Black Hole through Start-BlackHole.cmd with Administrator access."
    }
    if ($script:IsConnected) { Stop-BlackHole }
    if ($null -eq $script:Config) { Import-CurrentConfig }
    $script:Config = Ensure-LocalInbounds -Config $script:Config `
        -SocksPort ([int]$SocksPort.Text) -HttpPort ([int]$HttpPort.Text)
    $script:Config = Disable-XrayMux -Config $script:Config
    Apply-GrayIp

    $grayIp = $GrayAddress.Text.Trim()
    $parsedIp = $null
    if (-not [System.Net.IPAddress]::TryParse($grayIp, [ref]$parsedIp)) {
        throw "Gray IP must be a literal IPv4 or IPv6 address, not a hostname."
    }

    $metadata = Get-ConfigMetadata $script:Config
    if ($metadata.Security -ne 'tls') { throw "This version requires a TLS outbound." }
    if ($metadata.Network -notin @('ws','xhttp','splithttp')) {
        throw "This version supports WS or XHTTP. Current network: $($metadata.Network)"
    }
    if ([string]::IsNullOrWhiteSpace($metadata.Sni) -and [string]::IsNullOrWhiteSpace($metadata.Host)) {
        throw "The configuration has no SNI or Host, so Desync cannot be scoped safely."
    }

    $xray = Find-CoreFile 'xray.exe'
    if (-not $xray) { throw "xray.exe was not found in the core folder." }

    $configPath = Join-Path $RuntimeRoot 'active-config.json'
    $hostListPath = Join-Path $RuntimeRoot 'active-hosts.txt'
    $ipSetPath = Join-Path $RuntimeRoot 'active-gray-ip.txt'
    $xrayOut = Join-Path $RuntimeRoot 'xray-stdout.log'
    $xrayErr = Join-Path $RuntimeRoot 'xray-stderr.log'
    $winwsOut = Join-Path $RuntimeRoot 'desync-stdout.log'
    $winwsErr = Join-Path $RuntimeRoot 'desync-stderr.log'
    $winwsDebug = Join-Path $RuntimeRoot 'desync-debug.log'
    $winwsPreflightOut = Join-Path $RuntimeRoot 'desync-preflight-stdout.log'
    $winwsPreflightErr = Join-Path $RuntimeRoot 'desync-preflight-stderr.log'
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null

    Write-Utf8NoBom -Path $configPath -Content ($script:Config | ConvertTo-Json -Depth 100)
    $hosts = @($metadata.Sni, $metadata.Host) |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_.Trim() } | Select-Object -Unique
    Write-Utf8NoBom -Path $hostListPath -Content (($hosts -join [Environment]::NewLine) + [Environment]::NewLine)
    Write-Utf8NoBom -Path $ipSetPath -Content ($grayIp + [Environment]::NewLine)

    $profile = Get-SelectedProfile
    if ($profile.Enabled) {
        $winws = Find-CoreFile 'winws2.exe'
        if (-not $winws) {
            throw "The Desync core was not found. Extract the complete ZIP again."
        }
        $desyncArguments = Get-DesyncArguments -HostListPath $hostListPath -IpSetPath $ipSetPath
        Remove-Item -LiteralPath $winwsOut,$winwsErr,$winwsDebug,$winwsPreflightOut,$winwsPreflightErr `
            -Force -ErrorAction SilentlyContinue

        # Validate native dependencies, command-line parsing, and both Lua files
        # before opening WinDivert. This exits normally without intercepting traffic.
        $preflightArguments = @('--intercept=0') + $desyncArguments
        $preflightLine = Join-CommandPreview $preflightArguments
        $preflight = Start-Process -FilePath $winws -ArgumentList $preflightLine `
            -WorkingDirectory (Split-Path $winws -Parent) -WindowStyle Hidden -PassThru -Wait `
            -RedirectStandardOutput $winwsPreflightOut -RedirectStandardError $winwsPreflightErr
        if ($preflight.ExitCode -ne 0) {
            $detail = Get-NativeProcessDetails -Process $preflight `
                -LogPaths @($winwsPreflightOut,$winwsPreflightErr)
            throw "The Desync core preflight failed.`r`n$detail"
        }

        $desyncArguments = @("--debug=@$winwsDebug") + $desyncArguments
        $argumentLine = Join-CommandPreview $desyncArguments
        Write-AppLog "Starting Desync core profile=$($profile.Strategy)"
        Write-AppLog "DesyncCore $argumentLine"
        $script:WinwsProcess = Start-Process -FilePath $winws -ArgumentList $argumentLine `
            -WorkingDirectory (Split-Path $winws -Parent) -WindowStyle Hidden -PassThru `
            -RedirectStandardOutput $winwsOut -RedirectStandardError $winwsErr
        Start-Sleep -Milliseconds 700
        if ($script:WinwsProcess.HasExited) {
            $detail = Get-NativeProcessDetails -Process $script:WinwsProcess `
                -LogPaths @($winwsOut,$winwsErr,$winwsDebug)
            throw "The Desync core stopped immediately.`r`n$detail"
        }
    }

    Write-AppLog "Starting Xray with gray address $grayIp"
    $script:XrayProcess = Start-Process -FilePath $xray -ArgumentList @('run','-config',"`"$configPath`"") `
        -WorkingDirectory (Split-Path $xray -Parent) -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $xrayOut -RedirectStandardError $xrayErr
    Start-Sleep -Milliseconds 900
    if ($script:XrayProcess.HasExited) {
        $detail = if (Test-Path $xrayErr) { Get-Content $xrayErr -Raw -ErrorAction SilentlyContinue } else { "" }
        throw "Xray stopped immediately. $detail"
    }

    if ($SystemProxyCheck.IsChecked) {
        $script:ProxyBackup = Enable-WindowsProxy -Port ([int]$HttpPort.Text)
        Write-AppLog "Windows proxy enabled at 127.0.0.1:$($HttpPort.Text)"
    }
    Save-SessionState
    Set-AppStatus $true 'Connected'
    Write-AppLog 'Black Hole is running.'
}

function Save-CurrentConfig {
    if ($null -eq $script:Config) { Import-CurrentConfig }
    $script:Config = Ensure-LocalInbounds -Config $script:Config `
        -SocksPort ([int]$SocksPort.Text) -HttpPort ([int]$HttpPort.Text)
    $script:Config = Disable-XrayMux -Config $script:Config
    Apply-GrayIp
    $dialog = New-Object Microsoft.Win32.SaveFileDialog
    $dialog.Filter = 'Xray JSON (*.json)|*.json'
    $dialog.FileName = 'blackhole-config.json'
    if ($dialog.ShowDialog()) {
        Write-Utf8NoBom -Path $dialog.FileName -Content ($script:Config | ConvertTo-Json -Depth 100)
        Write-AppLog "Config saved: $($dialog.FileName)"
    }
}

function Save-UiSettings {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
    $settings = [ordered]@{
        profile = Get-SelectedProfileKey
        splitMode = Get-ComboText $SplitModeCombo
        splitPositions = Get-ComboText $SplitPositionsCombo
        fooling = Get-ComboText $FoolingCombo
        badSequence = [int]$BadSequence.Text
        autoTtlDelta = [int]$AutoTtlDelta.Text
        autoTtlMin = [int]$AutoTtlMin.Text
        autoTtlMax = [int]$AutoTtlMax.Text
        repeats = [int]$Repeats.Text
        fakeSni = $FakeSni.Text.Trim()
        socksPort = [int]$SocksPort.Text
        httpPort = [int]$HttpPort.Text
        systemProxy = [bool]$SystemProxyCheck.IsChecked
    }
    Write-Utf8NoBom -Path $UserSettingsPath -Content ($settings | ConvertTo-Json -Depth 5)
}

function Save-PersistentWorkspace {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
    Save-UiSettings
    if ([string]::IsNullOrWhiteSpace($ConfigInput.Text)) { return }
    $workspace = [ordered]@{
        configInput = $ConfigInput.Text
        grayAddress = $GrayAddress.Text.Trim()
        savedAt = (Get-Date).ToString('o')
    }
    Write-Utf8NoBom -Path $SavedWorkspacePath -Content ($workspace | ConvertTo-Json -Depth 5)
}

function Load-PersistentWorkspace {
    if (-not (Test-Path $SavedWorkspacePath)) { return }
    $workspace = Read-Utf8Text $SavedWorkspacePath | ConvertFrom-Json
    if ($null -eq $workspace.PSObject.Properties['configInput'] -or
        [string]::IsNullOrWhiteSpace([string]$workspace.configInput)) {
        return
    }
    $ConfigInput.Text = [string]$workspace.configInput
    Import-CurrentConfig
    if ($null -ne $workspace.PSObject.Properties['grayAddress'] -and
        -not [string]::IsNullOrWhiteSpace([string]$workspace.grayAddress)) {
        $GrayAddress.Text = [string]$workspace.grayAddress
        Apply-GrayIp
    }
    Write-AppLog 'Saved configuration and Gray IP restored.'
}

function Request-AutoSave {
    if (-not $script:IsUiInitialized -or $null -eq $script:AutoSaveTimer) { return }
    $script:AutoSaveTimer.Stop()
    $script:AutoSaveTimer.Start()
}

function Load-UiSettings {
    $script:LoadedUserSettings = Test-Path $UserSettingsPath
    $settingsPath = if ($script:LoadedUserSettings) { $UserSettingsPath } else { $ProfilePath }
    if (-not (Test-Path $settingsPath)) { return }
    $settings = Read-Utf8Text $settingsPath | ConvertFrom-Json
    Select-ComboText -ComboBox $SplitModeCombo -Text ([string]$settings.splitMode)
    Select-ComboText -ComboBox $FoolingCombo -Text ([string]$settings.fooling)
    Select-ComboText -ComboBox $SplitPositionsCombo -Text ([string]$settings.splitPositions)
    $BadSequence.Text = [string]$settings.badSequence
    $AutoTtlDelta.Text = [string]$settings.autoTtlDelta
    $AutoTtlMin.Text = [string]$settings.autoTtlMin
    $AutoTtlMax.Text = [string]$settings.autoTtlMax
    $Repeats.Text = [string]$settings.repeats
    Select-ComboText -ComboBox $FakeSni -Text ([string]$settings.fakeSni)
    $SocksPort.Text = [string]$settings.socksPort
    $HttpPort.Text = [string]$settings.httpPort
    $SystemProxyCheck.IsChecked = [bool]$settings.systemProxy
    if ($null -ne $settings.PSObject.Properties['profile']) {
        $profileText = switch ([string]$settings.profile) {
            'off' { 'Off (normal connection)' }
            'split' { 'Speed - Light split' }
            'balanced' { 'Balanced - BadSeq' }
            'badseq' { 'Balanced - BadSeq' }
            'severe_badseq' { 'Severe filtering - BadSeq' }
            'sni_spoof_badseq' { 'SNI spoof - WrongSeq' }
            'autottl' { 'Severe filtering - AutoTTL' }
            'Light split' { 'Speed - Light split' }
            'Fake + BadSeq' { 'Balanced - BadSeq' }
            'Fake + AutoTTL + Disorder' { 'Severe filtering - AutoTTL' }
            'custom' { 'Custom' }
            default { [string]$settings.profile }
        }
        Select-ComboText -ComboBox $ProfileCombo -Text $profileText
    }
}

foreach ($key in $script:Profiles.Keys) {
    $profileItem = New-Object System.Windows.Controls.ComboBoxItem
    $profileItem.Content = $key
    $profileItem.Tag = $key
    [void]$ProfileCombo.Items.Add($profileItem)
}
$ProfileCombo.SelectedIndex = 2
$ProfileDescription.Text = $script:Profiles[(Get-SelectedProfileKey)].Description
foreach ($combo in @($ProfileCombo,$SplitModeCombo,$SplitPositionsCombo,$FoolingCombo,$FakeSni)) {
    Enable-ComboBoxFullClickDropdown -ComboBox $combo
}

try { Load-UiSettings } catch {
    Write-AppLog "Settings could not be loaded: $($_.Exception.Message)"
}
$SocksPort.Text = if ([string]::IsNullOrWhiteSpace($SocksPort.Text)) { '1819' } else { $SocksPort.Text }
$HttpPort.Text = if ([string]::IsNullOrWhiteSpace($HttpPort.Text)) { '1920' } else { $HttpPort.Text }
if (-not $script:LoadedUserSettings) {
    Apply-SelectedProfileToAdvancedSettings
}
Update-AdvancedDependencyState
Update-SystemProxyLabel
$ProfileDescription.Text = $script:Profiles[(Get-SelectedProfileKey)].Description
try { Load-PersistentWorkspace } catch {
    Write-AppLog "Saved configuration could not be restored: $($_.Exception.Message)"
}

$script:AutoSaveTimer = New-Object Windows.Threading.DispatcherTimer
$script:AutoSaveTimer.Interval = [TimeSpan]::FromMilliseconds(700)
$script:AutoSaveTimer.Add_Tick({
    $script:AutoSaveTimer.Stop()
    try {
        Save-PersistentWorkspace
    } catch {
        Write-AppLog "Auto-save skipped: $($_.Exception.Message)"
    }
})
$script:IsUiInitialized = $true

$ProfileCombo.Add_SelectionChanged({
    param($sender, $eventArgs)
    try {
        $profileKey = Get-ProfileKeyFromItem $sender.SelectedItem
        if ([string]::IsNullOrWhiteSpace($profileKey)) { return }
        $ProfileDescription.Text = $script:Profiles[$profileKey].Description
        Apply-ProfileToAdvancedSettings -ProfileKey $profileKey
        Sync-CurrentConfigFromUi
        Request-AutoSave
        Write-AppLog "Profile applied: $profileKey | $(Get-AdvancedSettingsSummary)"
    } catch {
        Show-AppError $_.Exception.Message
    }
})

$FoolingCombo.Add_SelectionChanged({
    try {
        Update-AdvancedDependencyState
        Request-AutoSave
    } catch {
        Show-AppError $_.Exception.Message
    }
})

$HttpPort.Add_TextChanged({
    Update-SystemProxyLabel
    Request-AutoSave
})

foreach ($control in @(
    $ConfigInput,$GrayAddress,$SplitPositionsCombo,$BadSequence,$FakeSni,
    $AutoTtlDelta,$AutoTtlMin,$AutoTtlMax,$Repeats,$SocksPort
)) {
    if ($control -is [System.Windows.Controls.TextBox]) {
        $control.Add_TextChanged({ Request-AutoSave })
    } elseif ($control -is [System.Windows.Controls.ComboBox]) {
        $control.Add_SelectionChanged({ Request-AutoSave })
        $control.Add_LostKeyboardFocus({ Request-AutoSave })
    }
}
$SplitModeCombo.Add_SelectionChanged({ Request-AutoSave })
$SystemProxyCheck.Add_Checked({ Request-AutoSave })
$SystemProxyCheck.Add_Unchecked({ Request-AutoSave })

$ImportButton.Add_Click({
    try { Import-CurrentConfig } catch { Show-AppError $_.Exception.Message }
})

$OpenJsonButton.Add_Click({
    try {
        $dialog = New-Object Microsoft.Win32.OpenFileDialog
        $dialog.Filter = 'Xray JSON (*.json)|*.json|All files (*.*)|*.*'
        if ($dialog.ShowDialog()) {
            $ConfigInput.Text = Get-Content $dialog.FileName -Raw
            Import-CurrentConfig
        }
    } catch { Show-AppError $_.Exception.Message }
})

$ApplyGrayButton.Add_Click({
    try { Apply-GrayIp } catch { Show-AppError $_.Exception.Message }
})

$StartButton.Add_Click({
    try { Start-BlackHole } catch {
        $message = $_.Exception.Message
        try { Stop-BlackHole } catch {}
        Show-AppError $message
    }
})

$StopButton.Add_Click({
    try { Stop-BlackHole } catch { Show-AppError $_.Exception.Message }
})

$SaveConfigButton.Add_Click({
    try { Save-CurrentConfig } catch { Show-AppError $_.Exception.Message }
})

$PreviewCommandButton.Add_Click({
    try {
        if ($null -eq $script:Config) { Import-CurrentConfig }
        Apply-GrayIp
        $desyncArguments = Get-DesyncArguments -HostListPath '<runtime>\active-hosts.txt' `
            -IpSetPath '<runtime>\active-gray-ip.txt' -Preview
        if ($desyncArguments.Count -eq 0) {
            [System.Windows.MessageBox]::Show('The Off profile does not start the Desync core.', 'Black Hole') | Out-Null
        } else {
            $preview = 'DesyncCore.exe ' + (Join-CommandPreview $desyncArguments)
            $ConfigPreview.Text = $preview
            Write-AppLog 'Desync command preview generated.'
        }
    } catch { Show-AppError $_.Exception.Message }
})

$OpenLogsButton.Add_Click({
    try {
        New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
        Start-Process explorer.exe -ArgumentList "`"$RuntimeRoot`""
    } catch { Show-AppError $_.Exception.Message }
})

$ProcessTimer = New-Object Windows.Threading.DispatcherTimer
$ProcessTimer.Interval = [TimeSpan]::FromSeconds(1)
$ProcessTimer.Add_Tick({
    if (-not $script:IsConnected -or $script:IsStopping) { return }
    try {
        $failedComponent = $null
        if ($null -eq $script:XrayProcess -or $script:XrayProcess.HasExited) {
            $failedComponent = 'Xray'
        } else {
            $profile = Get-SelectedProfile
            if ($profile.Enabled -and
                ($null -eq $script:WinwsProcess -or $script:WinwsProcess.HasExited)) {
                $failedComponent = 'Desync core'
            }
        }
        if ($null -ne $failedComponent) {
            Write-AppLog "$failedComponent stopped unexpectedly."
            Stop-BlackHole
            Set-AppStatus $false 'Error'
            [System.Windows.MessageBox]::Show(
                "$failedComponent unexpectedly stopped. Check the Log tab and runtime logs.",
                'Black Hole', 'OK', 'Error'
            ) | Out-Null
        }
    } catch {
        Write-AppLog "Process monitor error: $($_.Exception.Message)"
    }
})
$ProcessTimer.Start()

$Window.Add_Closing({
    try { $script:AutoSaveTimer.Stop() } catch {}
    try { Save-PersistentWorkspace } catch {
        Write-AppLog "Settings could not be saved: $($_.Exception.Message)"
    }
    try { $ProcessTimer.Stop() } catch {}
    try { Stop-BlackHole } catch {}
})

$BlackHoleVideo.Add_MediaEnded({
    try {
        $BlackHoleVideo.Position = [TimeSpan]::Zero
        $BlackHoleVideo.Play()
    } catch {
        Write-AppLog "Background video loop skipped: $($_.Exception.Message)"
    }
})

$Window.Add_Loaded({
    Start-BackgroundVideo
})

Write-AppLog 'Black Hole 0.3.3 ready. Import a VLESS link or Xray JSON.'
try {
    [void]$Window.ShowDialog()
} finally {
    try { $script:InstanceMutex.ReleaseMutex() } catch {}
    try { $script:InstanceMutex.Dispose() } catch {}
}
