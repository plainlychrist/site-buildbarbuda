<?php

namespace Drupal\family_organization_permissions;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\Controller\EntityController;
use Drupal\Core\Entity\EntityManagerInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Symfony\Component\DependencyInjection\ContainerInterface;
use Symfony\Component\Routing\Route;

/**
 * Provides dynamic routes of the family_organization_permissions module.
 */
class FamilyOrganizationRoutes implements ContainerInjectionInterface {
	// Gives us t()
	use StringTranslationTrait;

  /**
   * The entity manager.
   *
   * @var \Drupal\Core\Entity\EntityManagerInterface
   */
  protected $entityManager;

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static($container->get('entity.manager'));
  }

  /**
   * Constructs a new FamilyOrganizationRoutes instance.
   *
   * @param \Drupal\Core\Entity\EntityManagerInterface $entity_manager
   *   The entity manager.
   */
  public function __construct(EntityManagerInterface $entity_manager) {
    $this->entityManager = $entity_manager;
	}

	public function routes() {
		$routes = array_merge($this->routes_for_type("family"), $this->routes_for_type("organization"));
		return $routes;
	}

  private function routes_for_type(string $type) {
		$routes = array();

    // Generate routes for each group that matches the type
    /** @var \Drupal\group\Entity\Group[] $groups */
    //$groups = $this->entityManager->getStorage('group')->loadByProperties(['type' => $type]);
    //foreach ($groups as $group) {
      // Mimic all the settings from: drupal dr entity.media.add_form
      // Defined in "core/lib/Drupal/Core/Entity/Routing/DefaultHtmlRouteProvider.php"
      $entity_type_id = 'media';
      //$route = new Route( sprintf('/%s/%s/media/add/{media_bundle}', $type, $group->id()) );
      $route = new Route( sprintf('/%s/{group}/media/add/{media_bundle}', $type) );
      $operation = 'default';
      $route->setDefaults([
        '_entity_form' => "{$entity_type_id}.{$operation}",
        'entity_type_id' => $entity_type_id,
      ]);
      $bundle_entity_type_id = 'media_bundle';
      $route->setDefault('_title_callback', EntityController::class . '::addBundleTitle');
      $route->setDefault('bundle_parameter', $bundle_entity_type_id);
      $bundle_entity_parameter = ['type' => 'entity:' . $bundle_entity_type_id];
      $bundle_entity_parameter['with_config_overrides'] = TRUE;
      $group_parameter = ['type' => 'entity:group'];
      $group_parameter['with_config_overrides'] = TRUE;
      $route->setOption('parameters', [$bundle_entity_type_id => $bundle_entity_parameter, 'group' => $group_parameter]);
      $route->setRequirement('_permission', 'create my families and organizations media');

      //$name = sprintf("entity.media.%s.%s.add_form", $type, $group->id());
      $name = sprintf("entity.media.%s.add_form", $type);
      $routes[$name] = $route;
    //}
    return $routes;
  }
}
