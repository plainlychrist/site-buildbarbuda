<?php

namespace Drupal\family_organization_permissions;

use Drupal\Core\DependencyInjection\ContainerInjectionInterface;
use Drupal\Core\Entity\EntityManagerInterface;
use Drupal\Core\StringTranslation\StringTranslationTrait;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Provides dynamic permissions of the family_organization_permissions module.
 */
class FamilyOrganizationPermissions implements ContainerInjectionInterface {
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
   * Constructs a new FamilyPermissions instance.
   *
   * @param \Drupal\Core\Entity\EntityManagerInterface $entity_manager
   *   The entity manager.
   */
  public function __construct(EntityManagerInterface $entity_manager) {
    $this->entityManager = $entity_manager;
	}

	public function permissions() {
		// NOTE: We don't need any dynamic permissions! The access-by-role approach works better
		return [];
		//$permissions = array_merge($this->permissions_for_type("family"), $this->permissions_for_type("organization"));
		//return $permissions;
	}

  private function permissions_for_type(string $type) {
		$permissions = [];

    // Generate permissions for each group that matches the type
    /** @var \Drupal\group\Entity\Group[] $groups */
    $groups = $this->entityManager->getStorage('group')->loadByProperties(['type' => $type]);
    foreach ($groups as $group) {
			$name = sprintf("view media for %s group %s", $type, $group->id());
			$permissions[$name] = [
				'title' => $this->t('View Media for @type <a href="/group/:id">@label</a>', ['@type' => $type, ':id' => $group->id(), '@label' => $group->label()]),
					'description' => [
						'#prefix' => '',
						'#markup' => $this->t('View media within the specific <em>@type</em> group.', array('@type' => $type)),
						'#suffix' => ''
					],
				];
    }
    return $permissions;
  }
}
