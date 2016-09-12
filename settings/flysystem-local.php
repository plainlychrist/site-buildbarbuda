$schemes = [
  'main' => [
    'driver' => 'local',
    'config' => [
      'root' => '/var/www/flysystem', // This will be treated similarly to Drupal's private file system.
    ],
  ],
];

$settings['flysystem'] = $schemes;
