<?php

namespace Drupal\family_organization_permissions;

use Drupal\Core\Access\AccessResult;
use Drupal\Core\Entity\EntityAccessControlHandler;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Session\AccountInterface;

/**
 * Defines an access controller for the media entity.
 */
class FamilyOrganizationMediaAccessController extends EntityAccessControlHandler {

  /**
   * {@inheritdoc}
   */
	protected function checkAccess(EntityInterface $entity, $operation, AccountInterface $account) {
		// @var Drupal\media_entity_image\Plugin\MediaEntity\Type\Image $entity->getType()
		// @var Drupal\media_entity\Entity\Media $entity
		if ($account && is_a($entity, 'Drupal\media_entity\Entity\Media')) {
			$rs = $account->getRoles();

			// @var Drupal\Core\Field\FieldItemList $entity->getFields()
			if ($entity->hasField('field_allowed_families_and_organ')) {
				$field_allowed_families_and_organ = $entity->get('field_allowed_families_and_organ');

				if (is_a($field_allowed_families_and_organ, 'Drupal\Core\Field\EntityReferenceFieldItemList')) {
					// @var \Drupal\Core\Entity\EntityInterface[] $allowed_families_and_organ
					$allowed_families_and_organ = $field_allowed_families_and_organ->referencedEntities();
					foreach ($allowed_families_and_organ as $allowed_family_or_org) {
						$role = sprintf('%s_%s_%s', 'view', $allowed_family_or_org->getGroupType()->id(), $allowed_family_or_org->id());
						\Drupal::logger('beckford')->notice('role ' . $role . ' with account roles ' . json_encode($rs));
						if (in_array($role, $rs)) {
							\Drupal::logger('beckford')->notice('FOUND role ' . $role);
						}
					}
				}
			}
		}

    if ($account->hasPermission('administer media')) {
      return AccessResult::allowed()->cachePerPermissions();
    }

    $is_owner = ($account->id() && $account->id() == $entity->getPublisherId()) ? TRUE : FALSE;
    switch ($operation) {
      case 'view':
	\Drupal::logger('beckford')->notice('checking view media permissions 4');
        return AccessResult::allowedIf($account->hasPermission('view media') && $entity->status->value);

      case 'update':
        return AccessResult::allowedIf(($account->hasPermission('update media') && $is_owner) || $account->hasPermission('update any media'))->cachePerPermissions()->cachePerUser()->addCacheableDependency($entity);

      case 'delete':
        return AccessResult::allowedIf(($account->hasPermission('delete media') && $is_owner) ||  $account->hasPermission('delete any media'))->cachePerPermissions()->cachePerUser()->addCacheableDependency($entity);
    }

    // No opinion.
    return AccessResult::neutral()->cachePerPermissions();
  }

  /**
   * {@inheritdoc}
   */
  protected function checkCreateAccess(AccountInterface $account, array $context, $entity_bundle = NULL) {
    return AccessResult::allowedIfHasPermission($account, 'create media');
  }

}
