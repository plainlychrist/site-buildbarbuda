<?php

namespace Drupal\family_organization_permissions\Plugin\Deriver;

use Drupal\Component\Plugin\Derivative\DeriverBase;
use Drupal\Core\Entity\EntityManagerInterface;
use Drupal\Core\Plugin\Discovery\ContainerDeriverInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Symfony\Component\DependencyInjection\ContainerInterface;

class FamilyOrganizationLinkDeriver extends DeriverBase implements ContainerDeriverInterface {
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
  public static function create(ContainerInterface $container, $base_plugin_id) {
    return new static($base_plugin_id, $container->get('entity.manager'));
  }

  /**
   * Constructs a new FamilyOrganizationDeriverLink instance.
   *
   * @param $base_plugin_id
   * @param \Drupal\Core\Entity\EntityManagerInterface $entity_manager
   *   The entity manager.
   */
  public function __construct($base_plugin_id, EntityManagerInterface $entity_manager) {
    $this->entityManager = $entity_manager;
	}

	public function getDerivativeDefinitions($base_plugin_definition) {
		#$links = array_merge($this->links_for_type("family", $base_plugin_definition), $this->links_for_type("organization", $base_plugin_definition));
    #return $links;
    $this->links_for_type("family", $base_plugin_definition);
    $this->links_for_type("organization", $base_plugin_definition);
    return $this->derivatives;
	}

  private function links_for_type(string $type, $base_plugin_definition) {
    // Generate links for each group that matches the type
    /** @var \Drupal\group\Entity\Group[] $groups */
    $groups = $this->entityManager->getStorage('group')->loadByProperties(['type' => $type]);
    foreach ($groups as $group) {
      $menu = sprintf("media.add.%s.%s.link", $type, $group->id());
      $this->derivatives[$menu] = $base_plugin_definition;
      $this->derivatives[$menu]['title'] = $this->t('Add Media for @type @label', ['@type' => $type, ':id' => $group->id(), '@label' => $group->label()]);
      $this->derivatives[$menu]['route_name'] = 'entity.media.' . $group->getGroupType()->id() . '.add_page';
      $this->derivatives[$menu]['route_parameters'] = ['group' => $group->id()];
      $this->derivatives[$menu]['parent'] = 'views.my_groups.page_1'; // /my-families-and-organizations, but doesn't work yet
    }
  }
}
